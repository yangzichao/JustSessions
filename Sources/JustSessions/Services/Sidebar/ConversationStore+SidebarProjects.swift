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

    func showProjectInSidebar(_ projectPath: String) {
        var updatedList = sidebarProjectList
        updatedList.show(projectPath)
        updateSidebarProjectList(updatedList)
    }

    /// Only changes sidebar membership. Session files, open tabs, names, and pins are kept.
    func removeProjectFromSidebar(_ projectPath: String) {
        removeProjectsFromSidebar([projectPath])
    }

    /// Saves one sidebar update for the whole selection, including projects on different hosts.
    func removeProjectsFromSidebar(_ projectPaths: Set<String>) {
        var updatedList = sidebarProjectList
        updatedList.remove(projectPaths)
        updateSidebarProjectList(updatedList)
    }

    private func updateSidebarProjectList(_ updatedList: SidebarProjectList) {
        guard updatedList != sidebarProjectList else { return }
        sidebarProjectList = updatedList
        sidebarProjectList.save(to: userDefaults)
    }
}
