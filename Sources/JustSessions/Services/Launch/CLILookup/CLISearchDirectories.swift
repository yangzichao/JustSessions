import Foundation

/// Where to look for `claude`, `codex`, and `agy`, in priority order.
enum CLISearchDirectories {
    static func standard(
        inheritedEnvironment: [String: String],
        loginShellDirectories: [String] = LoginShellPathReader.cachedPathDirectories,
        homeDirectory: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) -> [String] {
        let inheritedDirectories = LoginShellPathReader.parsePathDirectories(inheritedEnvironment["PATH"] ?? "")
        return deduplicated(
            inheritedDirectories
                + loginShellDirectories
                + wellKnownDirectories(homeDirectory: homeDirectory)
                + nvmDirectories(homeDirectory: homeDirectory, fileManager: fileManager)
        )
    }

    /// Fallbacks for when the login shell can't be read (slow rc file, unusual shell).
    static func wellKnownDirectories(homeDirectory: String) -> [String] {
        [
            "\(homeDirectory)/.local/bin",
            "\(homeDirectory)/.claude/local",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(homeDirectory)/.npm-global/bin",
            "\(homeDirectory)/.bun/bin",
            "\(homeDirectory)/.volta/bin",
            "\(homeDirectory)/Library/pnpm",
            "\(homeDirectory)/.local/share/mise/shims",
            "\(homeDirectory)/.asdf/shims",
            "/usr/bin",
            "/bin",
        ]
    }

    /// nvm keeps each Node version's global packages in its own bin directory. Newest version first.
    static func nvmDirectories(homeDirectory: String, fileManager: FileManager) -> [String] {
        let versionsDirectory = "\(homeDirectory)/.nvm/versions/node"
        let versions = (try? fileManager.contentsOfDirectory(atPath: versionsDirectory)) ?? []
        return versions
            .sorted { $0.compare($1, options: .numeric) == .orderedDescending }
            .map { "\(versionsDirectory)/\($0)/bin" }
    }

    /// CLIs that ship inside an app bundle and may never have been linked onto PATH.
    static func bundledExecutablePaths(named executableName: String) -> [String] {
        switch executableName {
        case "codex": ["/Applications/ChatGPT.app/Contents/Resources/codex"]
        default: []
        }
    }

    private static func deduplicated(_ directories: [String]) -> [String] {
        var seenDirectories = Set<String>()
        return directories.filter { seenDirectories.insert($0).inserted }
    }
}
