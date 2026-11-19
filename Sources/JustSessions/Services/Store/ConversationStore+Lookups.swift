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

    /// The subagent sessions `conversation` started, and theirs, at any depth, each once. A subagent that names one of
    /// the sessions above it as its own subagent is listed once, as the sidebar lists it once.
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

    /// How many subagent sessions `conversation` started, counting their own subagents, at any depth.
    func descendantSubagentCount(of conversation: Conversation) -> Int { descendantSubagents(of: conversation).count }
}
