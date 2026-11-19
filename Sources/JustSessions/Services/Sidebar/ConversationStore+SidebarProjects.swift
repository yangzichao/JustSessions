import Foundation

extension ConversationStore {
    var sidebarConversations: [Conversation] {
        sidebarProjection.conversations
    }

    var sidebarProjectGroups: [ProjectConversationGroup] {
        sidebarProjection.projectGroups
    }

    func filteredSidebarProjection(
        providerFilter: ConversationProviderFilter,
        recencyFilter: SessionRecencyFilter,
        statusFilter: SessionStatusFilter = .all,
        archiveFilter: SessionArchiveFilter = .hideArchived,
        searchText: String,
        messageMatchConversationIDs: Set<String> = []
    ) -> FilteredSidebarProjection {
        let projection = sidebarProjection
        let inputs = FilteredSidebarProjection.Inputs(
            projectionInputs: projection.inputs,
            titleAliases: titleAliases,
            providerFilter: providerFilter,
            recencyFilter: recencyFilter,
            statusFilter: statusFilter,
            archiveFilter: archiveFilter,
            archived: archivedSessions,
            running: sessionsRunning,
            waiting: sessionsWaitingForYou,
            searchText: searchText,
            messageMatchConversationIDs: messageMatchConversationIDs,
            recencyNow: Date(timeIntervalSinceReferenceDate: (Date.now.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
        )
        if let cachedFilteredSidebarProjection, cachedFilteredSidebarProjection.inputs == inputs {
            return cachedFilteredSidebarProjection
        }
        let filtered = FilteredSidebarProjection(inputs: inputs, projection: projection) { title(for: $0) }
        cachedFilteredSidebarProjection = filtered
        return filtered
    }

    private var sidebarProjection: SidebarProjection {
        let inputs = SidebarProjection.Inputs(
            conversationsRevision: conversationsRevision,
            hosts: hosts,
            sidebarProjectList: sidebarProjectList,
            pendingNewSessions: pendingNewSessions,
            projectDisplayNames: projectDisplayNames,
            pinnedItems: pinnedItems,
            hiddenProviders: hiddenConversationProviders
        )
        if let cachedSidebarProjection, cachedSidebarProjection.inputs == inputs { return cachedSidebarProjection }
        let projection = SidebarProjection(inputs: inputs, conversations: conversations)
        cachedSidebarProjection = projection
        return projection
    }

    func rememberSidebarProjects(_ projectPaths: Set<String>) {
        var updatedList = sidebarProjectList
        updatedList.remember(projectPaths)
        updateSidebarProjectList(updatedList)
    }

    var archivedProjectPaths: [String] {
        sidebarProjectList.removedProjectPaths
            .map { (projectPath: $0, displayName: projectDisplayName(forProjectPath: $0)) }
            .sorted { left, right in
                switch left.displayName.localizedCaseInsensitiveCompare(right.displayName) {
                case .orderedAscending: true
                case .orderedDescending: false
                case .orderedSame: left.projectPath < right.projectPath
                }
            }
            .map(\.projectPath)
    }

    func archivedProjectPaths(on host: SessionHost) -> [String] {
        archivedProjectPaths.filter { ProjectLocation(key: $0).host == host }
    }

    func archivedProjectCount(on host: SessionHost) -> Int {
        sidebarProjectList.removedProjectPaths.count { ProjectLocation(key: $0).host == host }
    }

    func showProjectInSidebar(_ projectPath: String) {
        var updatedList = sidebarProjectList
        updatedList.show(projectPath)
        updateSidebarProjectList(updatedList)
    }

    @discardableResult
    func addProjectToSidebar(
        folder: String,
        on host: SessionHost,
        creatingMissingFolder: Bool = false,
        resolver: RemoteFolderResolver = RemoteFolderResolver()
    ) async throws -> String {
        let projectPath = try await projectLocation(
            of: folder,
            on: host,
            creatingMissingFolder: creatingMissingFolder,
            resolver: resolver
        ).key
        showProjectInSidebar(projectPath)
        return projectPath
    }

    func removeProjectFromSidebar(_ projectPath: String) {
        removeProjectsFromSidebar([projectPath])
    }

    func removeProjectsFromSidebar(_ projectPaths: Set<String>) {
        var updatedList = sidebarProjectList
        updatedList.remove(projectPaths)
        updateSidebarProjectList(updatedList)
    }

    func deleteSessionsAndRemoveProject(_ projectPath: String) {
        deleteSessionsAndRemoveProjects([projectPath])
    }

    func deleteSessionsAndRemoveProjects(_ projectPaths: Set<String>) {
        let plan = deletionPlan(forProjects: projectPaths)
        guard plan.hasDeletableConversations else { return }
        closeAndDeleteConversations(plan.deletableConversations)
        removeProjectsFromSidebar(projectPaths)
    }

    private func updateSidebarProjectList(_ updatedList: SidebarProjectList) {
        guard updatedList != sidebarProjectList else { return }
        sidebarProjectList = updatedList
        sidebarProjectList.save(to: userDefaults)
    }
}
