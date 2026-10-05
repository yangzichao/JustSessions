import Foundation

extension ConversationStore {
    var sidebarConversations: [Conversation] {
        sidebarProjection.conversations
    }

    /// Includes saved empty projects; provider, recency, and search filters are applied by the browser.
    var sidebarProjectGroups: [ProjectConversationGroup] {
        sidebarProjection.projectGroups
    }

    /// `sidebarProjectGroups` narrowed by the browser's filters, with the filter bar's session counts.
    func filteredSidebarProjection(
        providerFilter: ConversationProviderFilter,
        recencyFilter: SessionRecencyFilter,
        searchText: String
    ) -> FilteredSidebarProjection {
        let projection = sidebarProjection
        let inputs = FilteredSidebarProjection.Inputs(
            projectionInputs: projection.inputs,
            titleAliases: titleAliases,
            providerFilter: providerFilter,
            recencyFilter: recencyFilter,
            searchText: searchText,
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
            pinnedItems: pinnedItems
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

    /// Archived projects for the restore list: by display name, then by key so equal names keep a stable order.
    var archivedProjectPaths: [String] {
        sidebarProjectList.removedProjectPaths.sorted { left, right in
            switch projectDisplayName(forProjectPath: left)
                .localizedCaseInsensitiveCompare(projectDisplayName(forProjectPath: right)) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: left < right
            }
        }
    }

    /// One host's archived projects, in the restore list's order, for the list opened from that host's heading.
    func archivedProjectPaths(on host: SessionHost) -> [String] {
        archivedProjectPaths.filter { ProjectLocation(key: $0).host == host }
    }

    func showProjectInSidebar(_ projectPath: String) {
        var updatedList = sidebarProjectList
        updatedList.show(projectPath)
        updateSidebarProjectList(updatedList)
    }

    /// From a host heading's +: lists a folder under its host before it has any sessions, or brings it back from the
    /// archive, and returns its project key. A folder typed for an SSH host is looked up there first, so a missing
    /// folder is reported and the project is keyed by the path the CLIs record.
    @discardableResult
    func addProjectToSidebar(
        folder: String,
        on host: SessionHost,
        resolver: RemoteFolderResolver = RemoteFolderResolver()
    ) async throws -> String {
        let projectPath = try await projectLocation(of: folder, on: host, resolver: resolver).key
        showProjectInSidebar(projectPath)
        return projectPath
    }

    /// Archiving only changes sidebar membership. Session files, open tabs, names, and pins are kept.
    func removeProjectFromSidebar(_ projectPath: String) {
        removeProjectsFromSidebar([projectPath])
    }

    /// Saves one sidebar update for the whole selection, including projects on different hosts.
    func removeProjectsFromSidebar(_ projectPaths: Set<String>) {
        var updatedList = sidebarProjectList
        updatedList.remove(projectPaths)
        updateSidebarProjectList(updatedList)
    }

    func deleteSessionsAndRemoveProject(_ projectPath: String) {
        deleteSessionsAndRemoveProjects([projectPath])
    }

    /// Deletes the projects' deletable sessions, now or after what holds them up, and archives the projects
    /// right away. Skipped sessions, such as those with open terminals, stay on disk and come back if a project is
    /// restored. When none of the sessions is deletable, the projects stay.
    func deleteSessionsAndRemoveProjects(_ projectPaths: Set<String>) {
        let plan = deletionPlan(forProjects: projectPaths)
        guard plan.hasDeletableConversations else { return }
        deleteConversations(plan.deletableConversations)
        removeProjectsFromSidebar(projectPaths)
    }

    private func updateSidebarProjectList(_ updatedList: SidebarProjectList) {
        guard updatedList != sidebarProjectList else { return }
        sidebarProjectList = updatedList
        sidebarProjectList.save(to: userDefaults)
    }
}
