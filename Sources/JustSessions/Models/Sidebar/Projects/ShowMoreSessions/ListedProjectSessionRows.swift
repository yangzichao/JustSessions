import Foundation

struct ListedProjectSessionRows {
    let rows: [ProjectSessionRow]
    let hiddenSessionCount: Int

    init(
        conversations: [Conversation],
        pendingNewSessions: [PendingNewSession],
        pinnedItems: PinnedItems,
        sessionLimit: Int?
    ) {
        let pinnedSessionCount = Self.pinnedSessionCount(in: conversations, pinnedItems: pinnedItems)
        let otherSessionCount = conversations.count - pinnedSessionCount
        let listedOtherSessionCount = ProjectSessionRowLimits.listedSessionCount(of: otherSessionCount, limit: sessionLimit)
        rows = ProjectSessionRow.ordered(
            conversations: Array(conversations.prefix(pinnedSessionCount + listedOtherSessionCount)),
            pendingNewSessions: pendingNewSessions,
            pinnedItems: pinnedItems
        )
        hiddenSessionCount = otherSessionCount - listedOtherSessionCount
    }

    var conversationIDs: [String] {
        rows.compactMap { row in
            if case .conversation(let conversation) = row { conversation.id } else { nil }
        }
    }

    static func hiddenPlace(
        of conversationID: String,
        in conversations: [Conversation],
        pinnedItems: PinnedItems,
        sessionLimit: Int?
    ) -> Int? {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return nil }
        let pinnedSessionCount = Self.pinnedSessionCount(in: conversations, pinnedItems: pinnedItems)
        let place = index - pinnedSessionCount
        let listedOtherSessionCount = ProjectSessionRowLimits.listedSessionCount(
            of: conversations.count - pinnedSessionCount, limit: sessionLimit
        )
        return place >= listedOtherSessionCount ? place : nil
    }

    private static func pinnedSessionCount(in conversations: [Conversation], pinnedItems: PinnedItems) -> Int {
        conversations.prefix { pinnedItems.isPinned(conversationID: $0.id) }.count
    }
}
