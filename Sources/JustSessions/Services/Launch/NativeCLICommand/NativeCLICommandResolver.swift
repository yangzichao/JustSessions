import Foundation

/// Sendable so a refresh can look up installed CLIs off the main actor. Its `FileManager` only checks paths, which
/// is safe from any thread.
struct NativeCLICommandResolver: @unchecked Sendable {
    let fileManager: FileManager
    let inheritedEnvironment: [String: String]
    private let searchDirectoriesOverride: [String]?

    init(
        fileManager: FileManager = .default,
        searchDirectories: [String]? = nil,
        inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.inheritedEnvironment = inheritedEnvironment
        self.searchDirectoriesOverride = searchDirectories
    }

    /// Computed per lookup so a CLI installed while the app is running is still found.
    var searchDirectories: [String] {
        searchDirectoriesOverride ?? CLISearchDirectories.standard(
            inheritedEnvironment: inheritedEnvironment,
            fileManager: fileManager
        )
    }

    /// PATH for spawned CLIs, so npm-installed ones can find `node` via `#!/usr/bin/env node`.
    var pathEnvironmentValue: String {
        searchDirectories.joined(separator: ":")
    }

    func resolve(
        conversation: Conversation,
        action: ConversationAction,
        adapter: any ConversationAdapter
    ) throws -> NativeCLICommand {
        try resolve(
            provider: conversation.provider,
            projectPath: conversation.projectPath,
            arguments: adapter.arguments(for: conversation, action: action)
        )
    }

    func resolveNewSession(provider: ConversationProvider, projectPath: String) throws -> NativeCLICommand {
        try resolve(provider: provider, projectPath: projectPath, arguments: [])
    }

    private func resolve(
        provider: ConversationProvider,
        projectPath: String,
        arguments: [String]
    ) throws -> NativeCLICommand {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: projectPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NativeCLICommandError.missingProject(projectPath)
        }

        guard let executablePath = executablePath(named: provider.executableName) else {
            throw NativeCLICommandError.missingExecutable(provider.executableName)
        }

        var environment = TerminalColorEnvironment.embeddedTerminalEnvironment(from: inheritedEnvironment)
        environment["PATH"] = pathEnvironmentValue

        return NativeCLICommand(
            executablePath: executablePath,
            arguments: arguments,
            workingDirectory: projectPath,
            environment: NativeCLICommand.environmentEntries(environment)
        )
    }

    func executablePath(named name: String) -> String? {
        let pathCandidates = searchDirectories.map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
        let bundledCandidates = searchDirectoriesOverride == nil ? CLISearchDirectories.bundledExecutablePaths(named: name) : []
        return (pathCandidates + bundledCandidates).first { fileManager.isExecutableFile(atPath: $0) }
    }
}
