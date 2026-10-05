import Foundation

extension ConversationStore {
    /// A listed session, or a subagent's session listed under one.
    func conversation(withID conversationID: String) -> Conversation? {
        conversationIndex.conversation(withID: conversationID) ?? subagentIndex.subagent(withID: conversationID)
    }

    /// The sessions the subagents of `conversation` ran in, newest first.
    func subagents(of conversation: Conversation) -> [Conversation] {
        subagentIndex.subagents(ofConversationID: conversation.id)
    }
}
