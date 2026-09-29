import Foundation

extension ConversationStore {
    func conversation(withID conversationID: String) -> Conversation? {
        conversations.first { $0.id == conversationID }
    }
}
