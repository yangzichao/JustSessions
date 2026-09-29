import Foundation

/// Project membership outlives its sessions. Explicitly removed projects stay hidden during discovery.
struct SidebarProjectList: Equatable {
    private static let listedPathsKey = "sidebarProjectPaths"
    private static let removedPathsKey = "removedSidebarProjectPaths"

    private(set) var projectPaths: Set<String> = []
    private(set) var removedProjectPaths: Set<String> = []

    static func load(from userDefaults: UserDefaults) -> SidebarProjectList {
        let removedPaths = Set(userDefaults.stringArray(forKey: removedPathsKey) ?? [])
        return SidebarProjectList(
            projectPaths: Set(userDefaults.stringArray(forKey: listedPathsKey) ?? []).subtracting(removedPaths),
            removedProjectPaths: removedPaths
        )
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(projectPaths.sorted(), forKey: Self.listedPathsKey)
        userDefaults.set(removedProjectPaths.sorted(), forKey: Self.removedPathsKey)
    }

    mutating func remember(_ discoveredPaths: Set<String>) {
        projectPaths.formUnion(discoveredPaths.subtracting(removedProjectPaths))
    }

    /// Starting a session explicitly brings its project back.
    mutating func show(_ projectPath: String) {
        removedProjectPaths.remove(projectPath)
        projectPaths.insert(projectPath)
    }

    mutating func remove(_ projectPath: String) {
        projectPaths.remove(projectPath)
        removedProjectPaths.insert(projectPath)
    }
}
