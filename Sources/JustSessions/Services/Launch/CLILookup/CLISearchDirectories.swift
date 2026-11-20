import Foundation

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

    static func nvmVersionsDirectory(homeDirectory: String) -> String {
        "\(homeDirectory)/.nvm/versions/node"
    }

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

    static func bundledExecutablePaths(named executableName: String) -> [String] {
        switch executableName {
        case "codex": ["/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"]
        default: []
        }
    }

    private static func deduplicated(_ directories: [String]) -> [String] {
        var seenDirectories = Set<String>()
        return directories.filter { seenDirectories.insert($0).inserted }
    }
}
