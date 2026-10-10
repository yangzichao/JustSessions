import Foundation

extension SidebarPinDrag.Row {
    /// A project's row among its host's projects.
    static func project(_ project: ProjectConversationGroup) -> Self {
        Self(rowID: projectRowID(project.projectPath), pinID: project.projectPath, isPinned: project.isPinned)
    }

    /// A row under a project; only a saved session's can be pinned.
    static func session(_ row: ProjectSessionRow, pinnedItems: PinnedItems) -> Self {
        switch row {
        case .conversation(let conversation):
            Self(rowID: row.id, pinID: conversation.id, isPinned: pinnedItems.isPinned(conversationID: conversation.id))
        case .pendingNewSession:
            Self(rowID: row.id, pinID: nil, isPinned: false)
        }
    }

    /// Apart from the ids of the rows under projects, `ProjectSessionRow.id`.
    static func projectRowID(_ projectPath: String) -> String {
        "project:\(projectPath)"
    }
}
