import Foundation

enum SidebarRowID: Hashable {
    case project(path: String)
    case emptyProject(path: String)
    case conversation(id: String)
    case pendingNewSession(id: UUID)
    case subagent(conversationID: String)
}
