import Foundation

enum NativeCLICommandError: LocalizedError {
    case missingExecutable(String)
    case missingProject(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let name): "Could not find the \(name) CLI. Install it or add it to your PATH."
        case .missingProject(let path): "The project directory no longer exists: \(path)"
        }
    }
}

struct NativeCLICommand {
    let executablePath: String
    let arguments: [String]
    let workingDirectory: String
    let environment: [String]
}

struct NativeCLICommandResolver {
    let fileManager: FileManager
    let searchDirectories: [String]
    let inheritedEnvironment: [String: String]

    init(
        fileManager: FileManager = .default,
        searchDirectories: [String]? = nil,
        inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.inheritedEnvironment = inheritedEnvironment
        let pathDirectories = (inheritedEnvironment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        self.searchDirectories = searchDirectories ?? pathDirectories + [
            NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"
        ]
    }

    func resolve(
        conversation: Conversation,
        action: ConversationAction,
        adapter: any ConversationAdapter
    ) throws -> NativeCLICommand {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: conversation.projectPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NativeCLICommandError.missingProject(conversation.projectPath)
        }

        let executableName = conversation.provider == .claude ? "claude" : "codex"
        guard let executablePath = executablePath(named: executableName) else {
            throw NativeCLICommandError.missingExecutable(executableName)
        }

        var environment = inheritedEnvironment
        environment["PATH"] = searchDirectories.reduce(into: [String]()) { directories, directory in
            if !directories.contains(directory) { directories.append(directory) }
        }.joined(separator: ":")
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        if environment["LANG"] == nil { environment["LANG"] = "en_US.UTF-8" }

        return NativeCLICommand(
            executablePath: executablePath,
            arguments: adapter.arguments(for: conversation, action: action),
            workingDirectory: conversation.projectPath,
            environment: environment.map { "\($0.key)=\($0.value)" }.sorted()
        )
    }

    func executablePath(named name: String) -> String? {
        for directory in searchDirectories {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if fileManager.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }
}
