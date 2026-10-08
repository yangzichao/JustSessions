import Foundation

/// Brings `index` up to date with the listed sessions while a window searches them, a few sessions at a time and the
/// most recently active first, so matches in recent sessions show first. Each searching window holds a use; once none
/// does, reading stops, and the text leaves memory after `unloadDelay` unless a search starts again.
@MainActor
final class SessionMessageIndexer: ObservableObject {
    struct Progress: Equatable {
        let readCount: Int
        let totalCount: Int
    }

    /// While sessions are read: how many of those the update had to read are done.
    @Published private(set) var progress: Progress?
    /// Goes up as more sessions can be searched, so a search runs again with them.
    @Published private(set) var revision = 0

    let index: SessionMessageIndex
    private var users: Set<UUID> = []
    private var updatedConversations: [Conversation]?
    private var updateTask: Task<Void, Never>?
    private var unloadTask: Task<Void, Never>?

    static let concurrentReadCount = 3
    var unloadDelay: Duration = .seconds(60)
    /// Progress and new matches show at most this often while sessions are read.
    var publishInterval: Duration = .milliseconds(250)

    init(index: SessionMessageIndex = SessionMessageIndex()) {
        self.index = index
    }

    func beginUse(by user: UUID) {
        users.insert(user)
        unloadTask?.cancel()
        unloadTask = nil
    }

    func endUse(by user: UUID) {
        guard users.remove(user) != nil, users.isEmpty else { return }
        updateTask?.cancel()
        updateTask = nil
        updatedConversations = nil
        progress = nil
        unloadTask = Task { [weak self, index, unloadDelay] in
            try? await Task.sleep(for: unloadDelay)
            guard !Task.isCancelled, self?.users.isEmpty == true else { return }
            await index.removeAll()
        }
    }

    /// Reads the sessions in `conversations` whose text is missing or stale; nothing to do while an update for the same
    /// list runs or has run.
    func update(with conversations: [Conversation]) {
        guard conversations != updatedConversations else { return }
        updatedConversations = conversations
        updateTask?.cancel()
        let index = index
        let mostRecentFirst = conversations.sorted { $0.updatedAt > $1.updatedAt }
        updateTask = Task { [weak self] in
            let sessionsToRead = await index.sessionsToRead(among: mostRecentFirst)
            guard !Task.isCancelled else { return }
            if !sessionsToRead.isEmpty {
                await self?.read(sessionsToRead, into: index)
                guard !Task.isCancelled else { return }
            }
            self?.progress = nil
            self?.revision += 1
            await index.removeSavedText(ofSessionsOtherThan: Set(conversations.map(\.id)))
        }
    }

    private func read(_ sessions: [(Conversation, SessionMessageTextFingerprint)], into index: SessionMessageIndex) async {
        let cache = index.cache
        var lastPublished = ContinuousClock.now
        progress = Progress(readCount: 0, totalCount: sessions.count)
        await withTaskGroup(of: (String, SessionMessageTextFingerprint, SearchableSessionText?).self) { group in
            var remaining = sessions.makeIterator()
            func readNext() {
                guard let (conversation, fingerprint) = remaining.next() else { return }
                group.addTask {
                    let text = await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
                    return (conversation.id, fingerprint, text)
                }
            }
            for _ in 0..<Self.concurrentReadCount { readNext() }
            var readCount = 0
            for await (conversationID, fingerprint, text) in group {
                if let text { await index.add(text, fingerprint: fingerprint, for: conversationID) }
                readCount += 1
                if ContinuousClock.now - lastPublished >= publishInterval {
                    lastPublished = .now
                    progress = Progress(readCount: readCount, totalCount: sessions.count)
                    revision += 1
                }
                if !Task.isCancelled { readNext() }
            }
        }
    }
}
