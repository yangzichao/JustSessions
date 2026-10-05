import Foundation

/// Sendable so a refresh can look up installed CLIs off the main actor. Its `FileManager` only checks paths, which
/// is safe from any thread.
struct NativeCLICommandResolver: @unchecked Sendable {
    let fileManager: FileManager
    let inheritedEnvironment: [String: String]
    let bundledTmuxRuntime: BundledTmuxRuntime?
    let tmuxSelection = ThisMacTmuxSelection()
    /// Nil starts Pi and OpenCode without the extension that reports their session.
    let liveSessionReporting: LiveSessionReporting?
    private let searchDirectoriesOverride: [String]?

    init(
        fileManager: FileManager = .default,
        searchDirectories: [String]? = nil,
        inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundledTmuxDirectory: URL? = BundledTmuxRuntime.appBundleDirectory,
        liveSessionReporting: LiveSessionReporting? = .thisApp
    ) {
        self.fileManager = fileManager
        self.inheritedEnvironment = inheritedEnvironment
        self.bundledTmuxRuntime = bundledTmuxDirectory.map { BundledTmuxRuntime(directory: $0) }
        self.liveSessionReporting = liveSessionReporting
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

    /// `startCommand` is one set in the New session sheet; nil starts the tool's own executable.
    func resolve(
        conversation: Conversation,
        action: ConversationAction,
        adapter: any ConversationAdapter,
        startCommand: String? = nil
    ) throws -> NativeCLICommand {
        try resolve(
            provider: conversation.provider,
            projectPath: conversation.projectPath,
            arguments: adapter.arguments(for: conversation, action: action),
            startCommand: startCommand
        )
    }

    func resolveNewSession(
        provider: ConversationProvider,
        projectPath: String,
        startCommand: String? = nil
    ) throws -> NativeCLICommand {
        try resolve(provider: provider, projectPath: projectPath, arguments: [], startCommand: startCommand)
    }

    private func resolve(
        provider: ConversationProvider,
        projectPath: String,
        arguments: [String],
        startCommand: String?
    ) throws -> NativeCLICommand {
        try requireProjectDirectory(projectPath)

        // A start command of your own is not looked up: the shell that runs it reports a missing one in the tab.
        let customStartCommand = CLIStartCommandLine.customCommand(startCommand)
        guard let executablePath = customStartCommand == nil
                ? executablePath(named: provider.executableName)
                : CLIStartCommandLine.thisMacShellPath else {
            throw NativeCLICommandError.missingExecutable(provider.executableName)
        }

        var environment = TerminalColorEnvironment.embeddedTerminalEnvironment(from: inheritedEnvironment)
        environment["PATH"] = pathEnvironmentValue
        // The session a CLI is in can change while it runs; see `followLiveSessions` and `followCodexThreads`.
        let reporterLaunch = liveSessionReporting?.launchAdditions(for: provider, environment: environment)
        environment.merge(reporterLaunch?.environment ?? [:]) { _, reporterValue in reporterValue }
        // Codex names the thread its CLI is in only in the terminal title, and only when asked.
        let followingArguments = provider == .codex ? CodexThreadTitle.launchArguments : reporterLaunch?.arguments ?? []
        let cliArguments = followingArguments + arguments

        return NativeCLICommand(
            executablePath: executablePath,
            arguments: customStartCommand.map {
                CLIStartCommandLine.thisMacShellArguments(startCommand: $0, arguments: cliArguments)
            } ?? cliArguments,
            workingDirectory: projectPath,
            environment: NativeCLICommand.environmentEntries(environment)
        )
    }

    func requireProjectDirectory(_ projectPath: String) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: projectPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NativeCLICommandError.missingProject(projectPath)
        }
    }

    func executablePath(named name: String) -> String? {
        let pathCandidates = searchDirectories.map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
        let bundledCandidates = searchDirectoriesOverride == nil ? CLISearchDirectories.bundledExecutablePaths(named: name) : []
        return (pathCandidates + bundledCandidates).first { fileManager.isExecutableFile(atPath: $0) }
    }
}
