import Foundation

extension ConversationStore {
    func conversation(withID conversationID: String) -> Conversation? {
        conversationIndex.conversation(withID: conversationID) ?? subagentIndex.subagent(withID: conversationID)
    }

    func subagents(of conversation: Conversation) -> [Conversation] {
        subagentIndex.subagents(ofConversationID: conversation.id)
    }

    func descendantSubagents(of conversation: Conversation) -> [Conversation] {
        var counted: Set<String> = [conversation.id]
        var pending = [conversation]
        var found: [Conversation] = []
        while let next = pending.popLast() {
            for subagent in subagents(of: next) where counted.insert(subagent.id).inserted {
                pending.append(subagent)
                found.append(subagent)
            }
        }
        return found
    }

    func descendantSubagentCount(of conversation: Conversation) -> Int { descendantSubagents(of: conversation).count }
}
