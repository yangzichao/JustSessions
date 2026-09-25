import Foundation

enum NativeCLICommandError: LocalizedError {
    case missingExecutable(String)
    case missingProject(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let name):
            "Could not find the \(name) CLI in your shell PATH or common install locations. "
                + "Install it, then check that `\(name)` runs in a new Terminal window."
        case .missingProject(let path): "The project directory no longer exists: \(path)"
        }
    }
}

struct NativeCLICommand {
    let executablePath: String
    let arguments: [String]
    let workingDirectory: String
    let environment: [String]

    func appendingArguments(_ extraArguments: [String]) -> NativeCLICommand {
        NativeCLICommand(
            executablePath: executablePath,
            arguments: arguments + extraArguments,
            workingDirectory: workingDirectory,
            environment: environment
        )
    }

    /// `environment` as a dictionary, for running the same executable outside a terminal.
    var environmentVariables: [String: String] {
        environment.reduce(into: [String: String]()) { variables, entry in
            guard let separator = entry.firstIndex(of: "=") else { return }
            variables[String(entry[..<separator])] = String(entry[entry.index(after: separator)...])
        }
    }
}

struct NativeCLICommandResolver {
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

        var environment = TerminalColorEnvironment.removingColorDisablingVariables(from: inheritedEnvironment)
        environment["PATH"] = pathEnvironmentValue
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        if environment["LANG"] == nil { environment["LANG"] = "en_US.UTF-8" }

        return NativeCLICommand(
            executablePath: executablePath,
            arguments: arguments,
            workingDirectory: projectPath,
            environment: environment.map { "\($0.key)=\($0.value)" }.sorted()
        )
    }

    func executablePath(named name: String) -> String? {
        let pathCandidates = searchDirectories.map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
        let bundledCandidates = searchDirectoriesOverride == nil ? CLISearchDirectories.bundledExecutablePaths(named: name) : []
        return (pathCandidates + bundledCandidates).first { fileManager.isExecutableFile(atPath: $0) }
    }
}
