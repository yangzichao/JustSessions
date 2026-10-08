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

    /// How many subagent sessions `conversation` started, counting their own subagents, at any depth. A subagent that
    /// names one of the sessions above it as its own subagent counts once, as the sidebar lists it once.
    func descendantSubagentCount(of conversation: Conversation) -> Int {
        var counted: Set<String> = [conversation.id]
        var pending = [conversation]
        while let next = pending.popLast() {
            for subagent in subagents(of: next) where counted.insert(subagent.id).inserted {
                pending.append(subagent)
            }
        }
        return counted.count - 1
    }
}
