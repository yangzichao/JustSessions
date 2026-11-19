import Foundation

enum WorkspaceLocation: Hashable {
    case tab(UUID)
    case conversation(String)

    static func shown(selectedTabID: UUID?, onlySelectedConversationID: String?) -> WorkspaceLocation? {
        if let selectedTabID { return .tab(selectedTabID) }
        return onlySelectedConversationID.map(WorkspaceLocation.conversation)
    }
}
