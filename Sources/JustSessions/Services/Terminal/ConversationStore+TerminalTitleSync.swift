import Foundation

extension ConversationStore {
    func synchronizeTerminalTitles() {
        let conversationsByID = conversations.reduce(into: [String: Conversation]()) {
            $0[$1.id] = $1
        }
        for session in terminalSessions {
            if let conversation = session.conversation,
               let current = conversationsByID[conversation.id] {
                session.synchronize(conversation: current, displayTitle: title(for: current))
            }
        }
    }

    /// A name the CLI in `tab` gave its session while it runs: the session's row lists it and the tab shows it, unless
    /// a name given in the app comes first. A session no refresh listed yet shows it on the tab alone.
    func applyChosenName(_ name: String, toSessionID sessionID: String, provider: ConversationProvider, shownIn tab: TerminalSession) {
        applySuggestedTitle(name, toSessionID: sessionID, provider: provider)
        let matchingConversation = conversations.first { $0.provider == provider && $0.sessionID == sessionID }
        tab.updateDisplayTitle(matchingConversation.map(title(for:)) ?? name)
    }
}
