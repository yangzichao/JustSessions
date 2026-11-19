import Foundation

enum ProjectSessionRow: Identifiable {
    case conversation(Conversation)
    case pendingNewSession(PendingNewSession)

    var id: String {
        switch self {
        case .conversation(let conversation): "conversation:\(conversation.id)"
        case .pendingNewSession(let pendingNewSession): "pending:\(pendingNewSession.id.uuidString)"
        }
    }

    static func ordered(
        conversations: [Conversation],
        pendingNewSessions: [PendingNewSession],
        pinnedItems: PinnedItems
    ) -> [ProjectSessionRow] {
        let pinnedConversationCount = conversations.prefix { pinnedItems.isPinned(conversationID: $0.id) }.count
        return conversations.prefix(pinnedConversationCount).map(Self.conversation)
            + pendingNewSessions.map(Self.pendingNewSession)
            + conversations.dropFirst(pinnedConversationCount).map(Self.conversation)
    }
}
