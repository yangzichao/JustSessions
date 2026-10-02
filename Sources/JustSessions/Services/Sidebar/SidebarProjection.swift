import Foundation

/// The sessions and projects the sidebar lists, before the browser's tool, recency, and search filters. The sidebar
/// asks for them on every store change, such as a CLI's status changing, and grouping a few thousand sessions takes
/// milliseconds, so the store keeps them until one of `Inputs` changes.
struct SidebarProjection {
    struct Inputs: Equatable {
        let conversationsRevision: Int
        let hosts: [SessionHost]
        let sidebarProjectList: SidebarProjectList
        let pendingNewSessions: [PendingNewSession]
        let projectDisplayNames: ProjectDisplayNames
        let pinnedItems: PinnedItems
    }

    let inputs: Inputs
    /// The listed hosts' sessions, leaving out projects removed from the sidebar.
    let conversations: [Conversation]
    /// Includes saved empty projects.
    let projectGroups: [ProjectConversationGroup]

    init(inputs: Inputs, conversations allConversations: [Conversation]) {
        self.inputs = inputs
        let listedHosts = Set(inputs.hosts)
        let removedProjectPaths = inputs.sidebarProjectList.removedProjectPaths
        conversations = allConversations.filter {
            listedHosts.contains($0.host) && !removedProjectPaths.contains($0.projectDirectoryKey)
        }
        projectGroups = ProjectConversationGroup.grouped(
            conversations,
            pendingNewSessions: inputs.pendingNewSessions.filter {
                listedHosts.contains(ProjectLocation(key: $0.projectDirectoryKey).host)
                    && !removedProjectPaths.contains($0.projectDirectoryKey)
            },
            retainedProjectPaths: inputs.sidebarProjectList.projectPaths.filter {
                listedHosts.contains(ProjectLocation(key: $0).host)
            },
            displayNames: inputs.projectDisplayNames,
            pinnedItems: inputs.pinnedItems
        )
    }
}
