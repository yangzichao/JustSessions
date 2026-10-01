import Foundation

/// Links tabs that wait for a session they can only recognize by its appearance, after each refresh of their host.
extension ConversationStore {
    /// Linking by appearance takes a session that is not among these. Other tabs on this Mac find their session
    /// through the files their CLI opens instead, so they need none.
    func sessionIDsKnownAtLaunch(of provider: ConversationProvider, on host: SessionHost) -> Set<String> {
        guard host != .thisMac || provider.linksNewSessionsByAppearance else { return [] }
        return Set(conversations.filter { $0.host == host && $0.provider == provider }.map(\.sessionID))
    }

    /// Links waiting tabs on the host to sessions that appeared since they started.
    func linkWaitingTabsByAppearance(on host: SessionHost) {
        let waitingSessions = terminalSessions.filter { $0.host == host && $0.isWaitingForAppearingSession }
        guard !waitingSessions.isEmpty else { return }
        let matches = AppearingSessionMatcher.matches(
            for: waitingSessions.compactMap(\.waitingTabForAppearingSession),
            in: conversations,
            alreadyLinkedConversationIDs: Set(terminalSessions.compactMap { $0.conversation?.id })
        )
        guard !matches.isEmpty else { return }
        for session in waitingSessions {
            guard let conversation = matches[session.id] else { continue }
            session.synchronize(conversation: conversation, displayTitle: title(for: conversation))
            adoptSessionTmuxName(for: session)
        }
        // Sidebar rows look up open terminals through the store, which does not see a tab's own changes.
        objectWillChange.send()
    }
}
