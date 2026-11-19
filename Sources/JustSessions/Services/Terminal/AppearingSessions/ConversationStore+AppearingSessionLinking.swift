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
            takenConversationIDs: conversationIDsTakenByTabs
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

    private var conversationIDsTakenByTabs: Set<String> {
        var taken = Set(terminalSessions.compactMap { $0.conversation?.id })
        for tab in terminalSessions where tab.isNewSessionAwaitingConversation {
            guard let sessionID = tab.preassignedSessionID,
                let preassigned = conversations.first(where: { $0.provider == tab.provider && $0.sessionID == sessionID })
            else { continue }
            taken.insert(preassigned.id)
        }
        return taken
    }
}
