import Foundation

enum SessionArchiveFilter: Hashable {
    case hideArchived
    case showArchived

    func includes(_ conversation: Conversation, archived: ArchivedSessions) -> Bool {
        self == .showArchived || !archived.isArchived(conversationID: conversation.id)
    }
}
