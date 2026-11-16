import Foundation

extension TerminalTabStrip {
    /// The order recovery saves, with every split separated. Ordinary project groups keep their place and their tabs
    /// first; tabs from cross-project splits join their project's end in the order those splits occur. A project with
    /// no ordinary group starts where its first split tab occurred. This matches separateAllSplits() without repeatedly
    /// rebuilding every remaining split's group keys while a selection is saved.
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
