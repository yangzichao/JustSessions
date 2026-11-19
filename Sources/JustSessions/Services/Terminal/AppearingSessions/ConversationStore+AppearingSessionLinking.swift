import Foundation

extension ConversationStore {
    func sessionIDsKnownAtLaunch(of provider: ConversationProvider, on host: SessionHost) -> Set<String> {
        guard host != .thisMac || provider.linksNewSessionsByAppearance else { return [] }
        return Set(conversations.filter { $0.host == host && $0.provider == provider }.map(\.sessionID))
    }

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
            let previousConversationID = session.conversation?.id
            session.synchronize(conversation: conversation, displayTitle: title(for: conversation))
            carryDeletionWhenClosed(of: session, from: previousConversationID)
            adoptSessionTmuxName(for: session)
        }
        persistOpenTabs()
        noteTabStateChanged()
    }
}
