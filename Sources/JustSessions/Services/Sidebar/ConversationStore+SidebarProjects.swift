import Foundation

extension ConversationStore {
    var sidebarConversations: [Conversation] {
        let listedHosts = Set(hosts)
        return conversations.filter {
            listedHosts.contains($0.host) && !sidebarProjectList.removedProjectPaths.contains($0.projectDirectoryKey)
        }
    }

    /// Includes saved empty projects; provider, recency, and search filters are applied by the browser.
    var sidebarProjectGroups: [ProjectConversationGroup] {
        let listedHosts = Set(hosts)
        return ProjectConversationGroup.grouped(
            sidebarConversations,
            pendingNewSessions: pendingNewSessions.filter {
                listedHosts.contains(ProjectLocation(key: $0.projectDirectoryKey).host)
                    && !sidebarProjectList.removedProjectPaths.contains($0.projectDirectoryKey)
            },
            retainedProjectPaths: sidebarProjectList.projectPaths.filter {
                listedHosts.contains(ProjectLocation(key: $0).host)
            },
            displayNames: projectDisplayNames,
            pinnedItems: pinnedItems
        )
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
        var updatedList = sidebarProjectList
        updatedList.remove(projectPath)
        updateSidebarProjectList(updatedList)
    }

    private func updateSidebarProjectList(_ updatedList: SidebarProjectList) {
        guard updatedList != sidebarProjectList else { return }
        sidebarProjectList = updatedList
        sidebarProjectList.save(to: userDefaults)
    }
}
