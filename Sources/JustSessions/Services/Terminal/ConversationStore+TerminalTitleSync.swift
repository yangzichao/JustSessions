import Foundation

extension ConversationStore {
    func synchronizeTerminalTitles() {
        for session in terminalSessions {
            if let conversation = session.conversation,
                let current = conversationIndex.conversation(withID: conversation.id)
            {
                session.synchronize(
                    conversation: current,
                    displayTitle: titleWhileWaitingForUnlistedSession(of: session) ?? title(for: current)
                )
            }
        }
    }

    func applyChosenName(_ name: String, toSessionID sessionID: String, provider: ConversationProvider, shownIn tab: TerminalSession) {
        applySuggestedTitle(name, toSessionID: sessionID, provider: provider, on: tab.host)
        let matchingConversation = conversations.first {
            $0.provider == provider && $0.host == tab.host && $0.sessionID == sessionID
        }
        tab.updateDisplayTitle(matchingConversation.map(title(for:)) ?? name)
    }
}
