import Foundation

extension TerminalTabStrip {
    var tabsWithSplitsSeparated: [Tab] {
        let crossProjectTabIDs = Set(splits.filter(\.spansProjects).flatMap(\.tabIDs))
        guard !crossProjectTabIDs.isEmpty else { return tabs }

        var tabsByProject: [String: [Tab]] = [:]
        for tab in tabs where !crossProjectTabIDs.contains(tab.id) {
            tabsByProject[tab.projectKey, default: []].append(tab)
        }
        let projectsWithOrdinaryGroups = Set(tabsByProject.keys)
        var projectOrder: [String] = []
        var orderedProjects: Set<String> = []
        for tab in tabs {
            if crossProjectTabIDs.contains(tab.id) {
                tabsByProject[tab.projectKey, default: []].append(tab)
                if projectsWithOrdinaryGroups.contains(tab.projectKey) { continue }
            }
            if orderedProjects.insert(tab.projectKey).inserted { projectOrder.append(tab.projectKey) }
        }
        var projected: [Tab] = []
        projected.reserveCapacity(tabs.count)
        for project in projectOrder { projected.append(contentsOf: tabsByProject[project] ?? []) }
        return projected
    }
}
