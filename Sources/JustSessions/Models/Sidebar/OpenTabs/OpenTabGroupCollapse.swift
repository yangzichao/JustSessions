import Foundation

struct OpenTabGroupCollapse: Equatable {
    private(set) var collapsedProjectKeys: Set<String> = []

    func isCollapsed(_ projectKey: String, whileSearching isSearching: Bool) -> Bool {
        !isSearching && collapsedProjectKeys.contains(projectKey)
    }

    func tabsInSight<Tab>(of groups: [TerminalTabGroup<Tab>], whileSearching isSearching: Bool) -> [Tab] {
        groups.filter { !isCollapsed($0.projectDirectoryKey, whileSearching: isSearching) }.flatMap(\.tabs)
    }

    mutating func toggle(_ projectKey: String) {
        if collapsedProjectKeys.remove(projectKey) == nil {
            collapsedProjectKeys.insert(projectKey)
        }
    }

    mutating func expand(_ projectKey: String) {
        collapsedProjectKeys.remove(projectKey)
    }

    mutating func collapse(_ projectKeys: [String]) {
        collapsedProjectKeys.formUnion(projectKeys)
    }

    mutating func expandAll() {
        collapsedProjectKeys.removeAll()
    }

    mutating func keepOnly(_ openProjectKeys: [String]) {
        collapsedProjectKeys.formIntersection(openProjectKeys)
    }
}
