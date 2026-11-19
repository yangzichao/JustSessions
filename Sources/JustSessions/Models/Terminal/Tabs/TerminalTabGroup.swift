import Foundation

struct TerminalTabGroup<Tab>: Identifiable {
    let projectDirectoryKey: String
    let tabs: [Tab]

    var id: String { projectDirectoryKey }

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
