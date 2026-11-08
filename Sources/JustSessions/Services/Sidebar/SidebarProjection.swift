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
        let hiddenProviders: HiddenConversationProviders
    }

    let inputs: Inputs
    /// The listed hosts' sessions, leaving out projects removed from the sidebar and the sessions of hidden CLIs.
    let conversations: [Conversation]
    /// Includes saved empty projects, but not a project whose only sessions are hidden CLIs'.
    let projectGroups: [ProjectConversationGroup]

    init(inputs: Inputs, conversations allConversations: [Conversation]) {
        self.inputs = inputs
        let listedHosts = Set(inputs.hosts)
        let removedProjectPaths = inputs.sidebarProjectList.removedProjectPaths
        let hiddenProviders = inputs.hiddenProviders
        let listedHostConversations = allConversations.filter {
            listedHosts.contains($0.host) && !removedProjectPaths.contains($0.projectDirectoryKey)
        }
        conversations = hiddenProviders.isEmpty
            ? listedHostConversations
            : listedHostConversations.filter { !hiddenProviders.hides($0.provider) }
        // Every project with sessions is remembered (`rememberSidebarProjects`), so one only hidden CLIs worked in
        // would otherwise stay as an empty project.
        let projectPathsOnlyHiddenCLIsUse = hiddenProviders.isEmpty
            ? []
            : Set(listedHostConversations.map(\.projectDirectoryKey)).subtracting(conversations.map(\.projectDirectoryKey))
        projectGroups = ProjectConversationGroup.grouped(
            conversations,
            pendingNewSessions: inputs.pendingNewSessions.filter {
                listedHosts.contains(ProjectLocation(key: $0.projectDirectoryKey).host)
                    && !removedProjectPaths.contains($0.projectDirectoryKey)
                    && !hiddenProviders.hides($0.provider)
            },
            retainedProjectPaths: inputs.sidebarProjectList.projectPaths.filter {
                listedHosts.contains(ProjectLocation(key: $0).host) && !projectPathsOnlyHiddenCLIsUse.contains($0)
            },
            displayNames: inputs.projectDisplayNames,
            pinnedItems: inputs.pinnedItems
        )
    }
}
