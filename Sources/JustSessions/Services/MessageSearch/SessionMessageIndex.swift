import Foundation

/// Every searching window's session text, held once in memory. A session's text is read once and saved in `cache`,
/// then read again only after the session changes.
actor SessionMessageIndex {
    private struct IndexedSession {
        let fingerprint: SessionMessageTextFingerprint
        let text: SearchableSessionText
    }

    nonisolated let cache: SessionMessageTextCache
    private var sessions: [String: IndexedSession] = [:]
    private var expectedFingerprints: [String: SessionMessageTextFingerprint] = [:]
    private var generation = 0

    init(cache: SessionMessageTextCache = .standard) {
        self.cache = cache
    }

    /// Of `conversations`, in their order, those whose text in memory is missing or older than the session. A newer
    /// generation wins even when an older read finishes later, and sessions no window lists leave memory.
    func sessionsToRead(
        among conversations: [Conversation], generation proposedGeneration: Int
    ) -> [(Conversation, SessionMessageTextFingerprint)] {
        guard proposedGeneration >= generation else { return [] }
        generation = proposedGeneration
        expectedFingerprints = Dictionary(
            uniqueKeysWithValues: conversations.map { ($0.id, SessionMessageTextFingerprint($0)) }
        )
        sessions = sessions.filter { expectedFingerprints[$0.key] == $0.value.fingerprint }
        return conversations.compactMap { conversation in
            guard let fingerprint = expectedFingerprints[conversation.id] else { return nil }
            return sessions[conversation.id]?.fingerprint == fingerprint ? nil : (conversation, fingerprint)
        }
    }

    /// Rejects writes from work that was active when the final search user ended, without dropping the text kept
    /// during the unload grace period.
    func advanceGeneration(to proposedGeneration: Int) {
        if proposedGeneration > generation { generation = proposedGeneration }
    }

    /// Saves only text from the latest desired generation. This keeps a cancelled, renamed, appended, or removed
    /// session read from replacing fresher text after another window has changed the shared session set.
    func add(
        _ text: SearchableSessionText,
        fingerprint: SessionMessageTextFingerprint,
        for conversationID: String,
        generation proposedGeneration: Int
    ) {
        guard proposedGeneration == generation, expectedFingerprints[conversationID] == fingerprint else { return }
        sessions[conversationID] = IndexedSession(fingerprint: fingerprint, text: text)
    }

    /// Each indexed session with `query`, and its first match. Stops when the calling task is cancelled.
    func matches(for query: SessionMessageQuery) throws -> [String: SessionMessageMatch] {
        var matches: [String: SessionMessageMatch] = [:]
        for (conversationID, session) in sessions {
            try Task.checkCancellation()
            if let match = session.text.firstMatch(of: query) { matches[conversationID] = match }
        }
        return matches
    }

    /// Frees the memory once no window searches; the cache keeps the text for the next search.
    func removeAll() {
        sessions = [:]
        expectedFingerprints = [:]
    }

    func removeSavedText(ofSessionsOtherThan listedConversationIDs: Set<String>, generation proposedGeneration: Int) {
        guard proposedGeneration == generation else { return }
        cache.removeText(ofSessionsOtherThan: listedConversationIDs)
    }

    /// Used by the performance measurement to report whether windows hold duplicate index entries.
    func sessionCount() -> Int { sessions.count }

    /// The session's text from the cache, or else read from the session and saved. A session saved before, which has
    /// changed since, is read with `readChanged`, which can resume a Codex session from its saved text. Nil when the
    /// session can't be read, or the read is cancelled; a later update tries again.
    nonisolated static func searchableText(
        of conversation: Conversation, fingerprint: SessionMessageTextFingerprint, cache: SessionMessageTextCache
    ) async -> SearchableSessionText? {
        switch cache.lookup(for: conversation.id, fingerprint: fingerprint) {
        case .current(let text):
            return SearchableSessionText(text)
        case .changed(let saved):
            guard let read = try? await SessionMessageTextReader.readChanged(conversation, resuming: saved),
                !Task.isCancelled
            else { return nil }
            cache.save(read.text, resumeState: read.resumeState, for: conversation.id, fingerprint: fingerprint)
            return SearchableSessionText(read.text)
        case .missing:
            guard let text = try? await SessionMessageTextReader.read(conversation), !Task.isCancelled else { return nil }
            cache.save(text, for: conversation.id, fingerprint: fingerprint)
            return SearchableSessionText(text)
        }
    }
}
