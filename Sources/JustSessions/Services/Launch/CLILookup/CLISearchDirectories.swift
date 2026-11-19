import Foundation

/// Where to look for each tool's CLI, in priority order. SSH hosts look in the same install folders when their login
/// shell doesn't find a CLI; see `RemoteCLIInstallFolders`.
enum CLISearchDirectories {
    static func standard(
        inheritedEnvironment: [String: String],
        loginShellDirectories: [String] = LoginShellEnvironment.cachedPathDirectories,
        homeDirectory: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) -> [String] {
        let inheritedDirectories = LoginShellEnvironment.parsePathDirectories(inheritedEnvironment["PATH"] ?? "")
        return deduplicated(
            inheritedDirectories
                + loginShellDirectories
                + wellKnownDirectories(homeDirectory: homeDirectory)
                + nvmDirectories(homeDirectory: homeDirectory, fileManager: fileManager)
        )
    }

    /// Fallbacks for when the login shell can't be read (slow rc file, unusual shell), and the folders where the CLIs'
    /// installers and package managers put them on macOS and Linux.
    static func wellKnownDirectories(homeDirectory: String) -> [String] {
        [
            "\(homeDirectory)/.local/bin",
            "\(homeDirectory)/.claude/local",
            "\(homeDirectory)/.opencode/bin",
            "\(homeDirectory)/.toolbox/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/home/linuxbrew/.linuxbrew/bin",
            "\(homeDirectory)/.npm-global/bin",
            "\(homeDirectory)/.bun/bin",
            "\(homeDirectory)/.volta/bin",
            "\(homeDirectory)/Library/pnpm",
            "\(homeDirectory)/.local/share/pnpm",
            "\(homeDirectory)/.local/share/mise/shims",
            "\(homeDirectory)/.asdf/shims",
            "/usr/bin",
            "/bin",
        ]
    }

    /// The folder of nvm's Node versions, each of which keeps its global packages in its own `bin`.
    static func nvmVersionsDirectory(homeDirectory: String) -> String {
        "\(homeDirectory)/.nvm/versions/node"
    }

    /// Whether one nvm version folder's name, such as `v22.3.0`, is a newer version than another's.
    static func isNewerNodeVersion(_ version: String, than otherVersion: String) -> Bool {
        version.compare(otherVersion, options: .numeric) == .orderedDescending
    }

    /// nvm keeps each Node version's global packages in its own bin directory. Newest version first.
    static func nvmDirectories(homeDirectory: String, fileManager: FileManager) -> [String] {
        let versionsDirectory = nvmVersionsDirectory(homeDirectory: homeDirectory)
        let versions = (try? fileManager.contentsOfDirectory(atPath: versionsDirectory)) ?? []
        return
            versions
            .sorted(by: isNewerNodeVersion)
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
