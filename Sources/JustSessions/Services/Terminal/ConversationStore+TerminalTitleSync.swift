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
}
