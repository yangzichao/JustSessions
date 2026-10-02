import Foundation

/// The open tabs of one project, which the tab bar shows together under the project's name.
struct TerminalTabGroup<Tab>: Identifiable {
    let projectDirectoryKey: String
    let tabs: [Tab]

    var id: String { projectDirectoryKey }

    /// One group per project, in the order each project's first tab appears.
    static func groups(of tabs: [Tab], projectDirectoryKey: (Tab) -> String) -> [TerminalTabGroup] {
        var projectKeysInOrder: [String] = []
        var tabsByProjectKey: [String: [Tab]] = [:]
        for tab in tabs {
            let projectKey = projectDirectoryKey(tab)
            if tabsByProjectKey[projectKey] == nil { projectKeysInOrder.append(projectKey) }
            tabsByProjectKey[projectKey, default: []].append(tab)
        }
        return projectKeysInOrder.map { TerminalTabGroup(projectDirectoryKey: $0, tabs: tabsByProjectKey[$0] ?? []) }
    }
}

extension TerminalTabGroup where Tab: Identifiable {
    /// The tabs a collapsed group hides: all but the selected one, which stays in sight. With none, collapsing the
    /// group would change nothing.
    func tabsHiddenWhenCollapsed(selectedTabID: Tab.ID?) -> [Tab] {
        tabs.filter { $0.id != selectedTabID }
    }
}
