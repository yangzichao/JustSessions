import Foundation

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

    func keepOnlyListedSessionsReturningThoseToRead(
        _ listedConversations: [Conversation], generation proposedGeneration: Int
    ) -> [(Conversation, SessionMessageTextFingerprint)] {
        guard proposedGeneration >= generation else { return [] }
        generation = proposedGeneration
        expectedFingerprints = Dictionary(
            uniqueKeysWithValues: listedConversations.map { ($0.id, SessionMessageTextFingerprint($0)) }
        )
        sessions = sessions.filter { expectedFingerprints[$0.key] == $0.value.fingerprint }
        return listedConversations.compactMap { conversation in
            guard let fingerprint = expectedFingerprints[conversation.id] else { return nil }
            return sessions[conversation.id]?.fingerprint == fingerprint ? nil : (conversation, fingerprint)
        }
    }

    func advanceGeneration(to proposedGeneration: Int) {
        if proposedGeneration > generation { generation = proposedGeneration }
    }

    func add(
        _ text: SearchableSessionText,
        fingerprint: SessionMessageTextFingerprint,
        for conversationID: String,
        generation proposedGeneration: Int
    ) {
        guard proposedGeneration == generation, expectedFingerprints[conversationID] == fingerprint else { return }
        sessions[conversationID] = IndexedSession(fingerprint: fingerprint, text: text)
    }

    func matches(for query: SessionMessageQuery) throws -> [String: SessionMessageMatch] {
        var matches: [String: SessionMessageMatch] = [:]
        for (conversationID, session) in sessions {
            try Task.checkCancellation()
            if let match = session.text.firstMatch(of: query) { matches[conversationID] = match }
        }
        return matches
    }

    func removeAll() {
        sessions = [:]
        expectedFingerprints = [:]
    }

    func removeSavedText(ofSessionsOtherThan listedConversationIDs: Set<String>, generation proposedGeneration: Int) {
        guard proposedGeneration == generation else { return }
        cache.removeText(ofSessionsOtherThan: listedConversationIDs)
    }

    func sessionCount() -> Int { sessions.count }

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
