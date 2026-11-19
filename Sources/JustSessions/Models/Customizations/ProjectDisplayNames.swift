import Foundation

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

    /// Works on the text alone, as views ask on every render: `URL(fileURLWithPath:)` would look the path up on this
    /// Mac's disk, and an SSH key such as `ssh://host/home/me/app` there as a path under the current folder.
    static func folderName(forProjectPath projectPath: String) -> String {
        (projectPath as NSString).lastPathComponent
    }

    func displayName(forProjectPath projectPath: String) -> String {
        customNamesByProjectPath[projectPath] ?? Self.folderName(forProjectPath: projectPath)
    }

    func hasCustomName(forProjectPath projectPath: String) -> Bool {
        customNamesByProjectPath[projectPath] != nil
    }

    mutating func rename(projectPath: String, to proposedName: String) {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == Self.folderName(forProjectPath: projectPath) {
            customNamesByProjectPath.removeValue(forKey: projectPath)
        } else {
            customNamesByProjectPath[projectPath] = trimmedName
        }
    }
}
