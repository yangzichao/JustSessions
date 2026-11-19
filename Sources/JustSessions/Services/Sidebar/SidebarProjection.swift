import Foundation

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
    let conversations: [Conversation]
    let projectGroups: [ProjectConversationGroup]

    init(inputs: Inputs, conversations allConversations: [Conversation]) {
        self.inputs = inputs
        let listedHosts = Set(inputs.hosts)
        let removedProjectPaths = inputs.sidebarProjectList.removedProjectPaths
        let hiddenProviders = inputs.hiddenProviders
        let listedHostConversations = allConversations.filter {
            listedHosts.contains($0.host) && !removedProjectPaths.contains($0.projectDirectoryKey)
        }
        conversations =
            hiddenProviders.isEmpty
            ? listedHostConversations
            : listedHostConversations.filter { !hiddenProviders.hides($0.provider) }
        let projectPathsOnlyHiddenCLIsUse =
            hiddenProviders.isEmpty
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
