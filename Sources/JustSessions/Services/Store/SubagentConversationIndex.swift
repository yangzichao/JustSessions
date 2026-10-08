import Foundation

/// Subagents' sessions by id, and under the session that started each, in list order. Built again whenever they
/// change, so a session row finds its subagents without going through every one.
struct SubagentConversationIndex {
    private let subagentsByID: [String: Conversation]
    private let subagentsByParentID: [String: [Conversation]]

    /// When two share an id, the first one listed wins. A session named as its own parent is left out.
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
