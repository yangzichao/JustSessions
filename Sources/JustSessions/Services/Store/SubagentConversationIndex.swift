import Foundation

struct SubagentConversationIndex {
    private let subagentsByID: [String: Conversation]
    private let subagentsByParentID: [String: [Conversation]]

    init(_ subagents: [Conversation]) {
        subagentsByID = Dictionary(subagents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var subagentsByParentID: [String: [Conversation]] = [:]
        for subagent in subagents {
            guard let parentID = subagent.parentID, parentID != subagent.id else { continue }
            subagentsByParentID[parentID, default: []].append(subagent)
        }
        self.subagentsByParentID = subagentsByParentID
    }

    func subagent(withID conversationID: String) -> Conversation? {
        subagentsByID[conversationID]
    }

    func subagents(ofConversationID conversationID: String) -> [Conversation] {
        subagentsByParentID[conversationID] ?? []
    }
}
