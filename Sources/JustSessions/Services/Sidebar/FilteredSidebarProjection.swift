import Foundation

struct FilteredSidebarProjection {
    struct Inputs: Equatable {
        let projectionInputs: SidebarProjection.Inputs
        let titleAliases: ConversationTitleAliases
        let providerFilter: ConversationProviderFilter
        let recencyFilter: SessionRecencyFilter
        let statusFilter: SessionStatusFilter
        let archiveFilter: SessionArchiveFilter
        let archived: ArchivedSessions
        let running: SessionsRunning
        let waiting: SessionsWaitingForYou
        let searchText: String
        let messageMatchConversationIDs: Set<String>
        let recencyNow: Date
    }

    let inputs: Inputs
    let projects: [ProjectConversationGroup]
    let listedConversationIDs: Set<String>
    let allSessionCount: Int
    let archivedSessionCount: Int
    let recentSessionCount: Int
    let runningSessionCount: Int
    let waitingSessionCount: Int

    init(inputs: Inputs, projection: SidebarProjection, title: (Conversation) -> String) {
        self.inputs = inputs
        let toolConversations = projection.conversations.filter { inputs.providerFilter.includes($0.provider) }
        archivedSessionCount = toolConversations.filter { inputs.archived.isArchived(conversationID: $0.id) }.count
        let countedConversations = toolConversations.filter { inputs.archiveFilter.includes($0, archived: inputs.archived) }
        allSessionCount = countedConversations.count
        recentSessionCount =
            countedConversations
            .filter { SessionRecencyFilter.recent.includes($0, now: inputs.recencyNow) }
            .count
        runningSessionCount = countedConversations.filter { inputs.running.conversationIDs.contains($0.id) }.count
        waitingSessionCount = countedConversations.filter { inputs.waiting.conversationIDs.contains($0.id) }.count
        let filteredProjects = SidebarProjectFiltering.projects(
            projection.projectGroups,
            providerFilter: inputs.providerFilter,
            recencyFilter: inputs.recencyFilter,
            statusFilter: inputs.statusFilter,
            archiveFilter: inputs.archiveFilter,
            archived: inputs.archived,
            running: inputs.running,
            waiting: inputs.waiting,
            now: inputs.recencyNow
        )
        projects = SidebarProjectFiltering.projects(
            filteredProjects,
            matching: inputs.searchText,
            title: title,
            messageMatchConversationIDs: inputs.messageMatchConversationIDs
        )
        listedConversationIDs = Set(projects.lazy.flatMap(\.conversations).map(\.id))
    }
}
