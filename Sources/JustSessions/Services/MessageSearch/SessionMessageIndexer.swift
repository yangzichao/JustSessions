import Foundation

/// Brings the shared `index` up to date with every searching window's listed sessions, a few sessions at a time and
/// the most recently active first. Each window holds a use; once none does, reading stops, and the text leaves memory
/// after `unloadDelay` unless a search starts again.
@MainActor
final class SessionMessageIndexer: ObservableObject {
    typealias Reader = @Sendable (
        Conversation, SessionMessageTextFingerprint, SessionMessageTextCache
    ) async -> SearchableSessionText?

    struct Progress: Equatable {
        let readCount: Int
        let totalCount: Int
    }

    /// While sessions are read: how many of those the current update had to read are done.
    @Published private(set) var progress: Progress?
    /// Goes up as more sessions can be searched, so every window's search runs again with them.
    @Published private(set) var revision = 0

    let index: SessionMessageIndex
    private let reader: Reader
    private var users: Set<UUID> = []
    private var conversationsByUser: [UUID: [Conversation]] = [:]
    /// Hosts explicitly removed from the shared workspace stay out even while another window still has an old list.
    private var removedHosts: Set<SessionHost> = []
    private var desiredConversations: [Conversation] = []
    private var desiredGeneration = 0
    private var activeUpdateID: UUID?
    private var updateTask: Task<Void, Never>?
    private var unloadTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    var waitBeforeRetry: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    static let concurrentReadCount = 3
    var unloadDelay: Duration = .seconds(60)
    /// Progress and new matches show at most this often while sessions are read.
    var publishInterval: Duration = .milliseconds(250)
    var retryDelay: Duration = .seconds(1)

    init(
        index: SessionMessageIndex = SessionMessageIndex(),
        reader: @escaping Reader = { conversation, fingerprint, cache in
            await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
        }
    ) {
        self.index = index
        self.reader = reader
    }

    func beginUse(by user: UUID) {
        users.insert(user)
        unloadTask?.cancel()
        unloadTask = nil
    }

    func endUse(by user: UUID) {
        guard users.remove(user) != nil else { return }
        conversationsByUser[user] = nil
        guard !users.isEmpty else {
            desiredGeneration &+= 1
            let generation = desiredGeneration
            retryTask?.cancel()
            retryTask = nil
            consecutiveFailures = 0
            desiredConversations = []
            activeUpdateID = nil
            updateTask?.cancel()
            updateTask = nil
            progress = nil
            let index = index
            unloadTask = Task { [weak self, index, unloadDelay] in
                await index.advanceGeneration(to: generation)
                try? await Task.sleep(for: unloadDelay)
                guard !Task.isCancelled, self?.users.isEmpty == true else { return }
                await index.removeAll()
            }
            return
        }

        Task { [weak self] in await self?.applyDesiredConversations() }
    }

    /// Invalidates a host for every user. Another window may still hold the old host list until its next refresh.
    func removeHost(_ host: SessionHost) {
        guard removedHosts.insert(host).inserted else { return }
        Task { [weak self] in await self?.applyDesiredConversations() }
    }

    /// Lets sessions from an explicitly re-added host enter the index again.
    func restoreHost(_ host: SessionHost) {
        guard removedHosts.remove(host) != nil else { return }
        Task { [weak self] in await self?.applyDesiredConversations() }
    }

    /// Adds this user's listed sessions to the shared desired set. A user can change its host or filters without
    /// pruning another user's sessions, and an update already reading for another user is allowed to finish.
    func update(with conversations: [Conversation], for user: UUID) async {
        guard users.contains(user) else { return }
        // Query edits and progress publications usually carry the same list. Failed reads have their own timer.
        guard conversationsByUser[user] != conversations else { return }
        conversationsByUser[user] = conversations
        await applyDesiredConversations()
    }

    private func applyDesiredConversations() async {
        let conversations = unionOfUsersConversations()
        guard conversations != desiredConversations else { return }
        retryTask?.cancel()
        retryTask = nil
        consecutiveFailures = 0
        desiredConversations = conversations
        desiredGeneration &+= 1
        let generation = desiredGeneration
        let sessions = await index.sessionsToRead(among: conversations, generation: generation)
        guard generation == desiredGeneration, !users.isEmpty else { return }
        guard updateTask == nil else { return }
        startUpdate(sessions, conversations: conversations, generation: generation)
    }

    private func unionOfUsersConversations() -> [Conversation] {
        var byID: [String: Conversation] = [:]
        for conversations in conversationsByUser.values {
            for conversation in conversations where !removedHosts.contains(conversation.host) {
                if let found = byID[conversation.id], found.updatedAt > conversation.updatedAt { continue }
                byID[conversation.id] = conversation
            }
        }
        return byID.values.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }
    }

    private func startUpdate(
        _ sessions: [(Conversation, SessionMessageTextFingerprint)],
        conversations: [Conversation],
        generation: Int
    ) {
        let id = UUID()
        activeUpdateID = id
        let index = index
        let reader = reader
        updateTask = Task { [weak self] in
            var hadFailures = false
            if !sessions.isEmpty {
                hadFailures = await self?.read(sessions, generation: generation, into: index, reader: reader) ?? false
            }
            await self?.finishUpdate(id: id, conversations: conversations, generation: generation, hadFailures: hadFailures)
        }
    }

    private func finishUpdate(id: UUID, conversations: [Conversation], generation: Int, hadFailures: Bool) async {
        guard activeUpdateID == id else { return }
        activeUpdateID = nil
        updateTask = nil
        guard !users.isEmpty else { return }

        guard generation == desiredGeneration, conversations == desiredConversations else {
            let nextGeneration = desiredGeneration
            let nextConversations = desiredConversations
            let sessions = await index.sessionsToRead(among: nextConversations, generation: nextGeneration)
            guard nextGeneration == desiredGeneration, !users.isEmpty, updateTask == nil else { return }
            startUpdate(sessions, conversations: nextConversations, generation: nextGeneration)
            return
        }

        progress = nil
        revision &+= 1
        await index.removeSavedText(
            ofSessionsOtherThan: Set(conversations.map(\.id)), generation: generation
        )
        guard generation == desiredGeneration, !users.isEmpty else { return }
        if hadFailures { scheduleRetry(generation: generation) } else { consecutiveFailures = 0 }
    }

    /// A permanently unreadable file backs off to one attempt every 30 seconds, and closing search cancels the wait.
    private func scheduleRetry(generation: Int) {
        retryTask?.cancel()
        let delay = min(retryDelay * (1 << min(consecutiveFailures, 5)), .seconds(30))
        consecutiveFailures += 1
        retryTask = Task { [weak self, waitBeforeRetry] in
            do { try await waitBeforeRetry(delay) } catch { return }
            guard !Task.isCancelled, let self, !self.users.isEmpty,
                  generation == self.desiredGeneration else { return }
            self.retryTask = nil
            let conversations = self.desiredConversations
            let sessions = await self.index.sessionsToRead(among: conversations, generation: generation)
            guard !Task.isCancelled, generation == self.desiredGeneration, self.updateTask == nil else { return }
            self.startUpdate(sessions, conversations: conversations, generation: generation)
        }
    }

    private func read(
        _ sessions: [(Conversation, SessionMessageTextFingerprint)],
        generation: Int,
        into index: SessionMessageIndex,
        reader: @escaping Reader
    ) async -> Bool {
        let cache = index.cache
        var hadFailures = false
        var lastPublished = ContinuousClock.now
        progress = Progress(readCount: 0, totalCount: sessions.count)
        await withTaskGroup(of: (String, SessionMessageTextFingerprint, SearchableSessionText?).self) { group in
            var remaining = sessions.makeIterator()
            func readNext() {
                guard let (conversation, fingerprint) = remaining.next() else { return }
                group.addTask {
                    let text = await reader(conversation, fingerprint, cache)
                    return (conversation.id, fingerprint, text)
                }
            }
            for _ in 0..<Self.concurrentReadCount { readNext() }
            var readCount = 0
            for await (conversationID, fingerprint, text) in group {
                if let text {
                    await index.add(text, fingerprint: fingerprint, for: conversationID, generation: generation)
                } else {
                    hadFailures = true
                }
                readCount += 1
                if generation == desiredGeneration, ContinuousClock.now - lastPublished >= publishInterval {
                    lastPublished = .now
                    progress = Progress(readCount: readCount, totalCount: sessions.count)
                    revision &+= 1
                }
                if !Task.isCancelled { readNext() }
            }
        }
        return hadFailures && !Task.isCancelled
    }
}
