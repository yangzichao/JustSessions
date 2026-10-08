import Foundation

/// The rows under a session for the subagents it started, shown only once you expand the session: each subagent, then,
/// while that one is expanded too, its own.
struct SidebarSubagentRows {
    struct Row: Identifiable, Equatable {
        let conversation: Conversation
        /// 1 for a subagent of a listed session, 2 for one of its subagents, and so on.
        let depth: Int
        let subagentCount: Int
        var id: String { conversation.id }
    }

    /// The sessions whose subagents show. Every session starts collapsed.
    private(set) var expandedConversationIDs: Set<String> = []

    func isExpanded(_ conversationID: String) -> Bool {
        expandedConversationIDs.contains(conversationID)
    }

    mutating func toggle(_ conversationID: String) {
        if expandedConversationIDs.remove(conversationID) == nil {
            expandedConversationIDs.insert(conversationID)
        }
    }

    /// The rows under `conversation`, in order, while it is expanded; none while it is collapsed. A subagent that names
    /// one of the sessions above it as its own subagent shows once.
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
