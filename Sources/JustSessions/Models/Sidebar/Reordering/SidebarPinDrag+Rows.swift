import Foundation

extension SidebarPinDrag.Row {
    static func project(_ project: ProjectConversationGroup) -> Self {
        Self(rowID: projectRowID(project.projectPath), pinID: project.projectPath, isPinned: project.isPinned)
    }

    static func session(_ row: ProjectSessionRow, pinnedItems: PinnedItems) -> Self {
        switch row {
        case .conversation(let conversation):
            Self(rowID: row.id, pinID: conversation.id, isPinned: pinnedItems.isPinned(conversationID: conversation.id))
        case .pendingNewSession:
            Self(rowID: row.id, pinID: nil, isPinned: false)
        }
    }

    static func projectRowID(_ projectPath: String) -> String {
        "project:\(projectPath)"
    }
}
