import Foundation

extension ConversationStore {
    func conversation(withID conversationID: String) -> Conversation? {
        conversationIndex.conversation(withID: conversationID)
    }
}
