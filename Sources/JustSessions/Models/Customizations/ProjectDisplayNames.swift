import Foundation

/// Custom project names chosen in JustSessions, keyed by `projectDirectoryKey`.
/// Projects without a custom name fall back to their folder name.
struct ProjectDisplayNames: Equatable {
    static let userDefaultsKey = "projectAliases"

    private(set) var customNamesByProjectPath: [String: String]

    init(customNamesByProjectPath: [String: String] = [:]) {
        self.customNamesByProjectPath = customNamesByProjectPath
    }

    static func load(from userDefaults: UserDefaults) -> ProjectDisplayNames {
        let storedNames = userDefaults.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
        return ProjectDisplayNames(customNamesByProjectPath: storedNames)
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(customNamesByProjectPath, forKey: Self.userDefaultsKey)
    }

    static func folderName(forProjectPath projectPath: String) -> String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    func displayName(forProjectPath projectPath: String) -> String {
        customNamesByProjectPath[projectPath] ?? Self.folderName(forProjectPath: projectPath)
    }

    func hasCustomName(forProjectPath projectPath: String) -> Bool {
        customNamesByProjectPath[projectPath] != nil
    }

    /// An empty name, or one equal to the folder name, clears the custom name.
    mutating func rename(projectPath: String, to proposedName: String) {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == Self.folderName(forProjectPath: projectPath) {
            customNamesByProjectPath.removeValue(forKey: projectPath)
        } else {
            customNamesByProjectPath[projectPath] = trimmedName
        }
    }
}
