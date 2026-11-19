import Foundation

struct SidebarSubagentRows {
    static let showsSubagentsUserDefaultsKey = "sidebarShowsSubagentSessions"

    struct Row: Identifiable, Equatable {
        let conversation: Conversation
        let depth: Int
        let subagentCount: Int
        var id: String { conversation.id }
    }

    private(set) var expandedConversationIDs: Set<String> = []

    func isExpanded(_ conversationID: String) -> Bool {
        expandedConversationIDs.contains(conversationID)
    }

    mutating func toggle(_ conversationID: String) {
        if expandedConversationIDs.remove(conversationID) == nil {
            expandedConversationIDs.insert(conversationID)
        }
    }

    func rows(under conversation: Conversation, subagents: (Conversation) -> [Conversation]) -> [Row] {
        var rows: [Row] = []
        var shownIDs: Set<String> = [conversation.id]
        appendRows(under: conversation, depth: 1, subagents: subagents, shownIDs: &shownIDs, to: &rows)
        return rows
    }

    private func appendRows(
        under conversation: Conversation,
        depth: Int,
        subagents: (Conversation) -> [Conversation],
        shownIDs: inout Set<String>,
        to rows: inout [Row]
    ) {
        guard isExpanded(conversation.id) else { return }
        for subagent in subagents(conversation) where shownIDs.insert(subagent.id).inserted {
            let subagentsOfSubagent = subagents(subagent)
            rows.append(Row(conversation: subagent, depth: depth, subagentCount: subagentsOfSubagent.count))
            appendRows(under: subagent, depth: depth + 1, subagents: subagents, shownIDs: &shownIDs, to: &rows)
        }
    }
}
