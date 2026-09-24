import AppKit
import Foundation

enum TerminalLaunchError: LocalizedError {
    case missingExecutable(String)
    case missingProject(String)
    case terminalUnavailable
    case failedToOpen

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let name): "Could not find the \(name) CLI. Install it or add it to your PATH."
        case .missingProject(let path): "The project directory no longer exists: \(path)"
        case .terminalUnavailable: "Terminal.app is unavailable."
        case .failedToOpen: "Terminal could not open the launch script."
        }
    }
}

struct TerminalLauncher {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @MainActor
    func open(_ conversation: Conversation, action: ConversationAction, adapter: any ConversationAdapter) throws {
        guard fileManager.fileExists(atPath: conversation.projectPath) else {
            throw TerminalLaunchError.missingProject(conversation.projectPath)
        }
        let executableName = conversation.provider == .claude ? "claude" : "codex"
        guard let executable = findExecutable(named: executableName) else {
            throw TerminalLaunchError.missingExecutable(executableName)
        }
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            throw TerminalLaunchError.terminalUnavailable
        }

        let scriptDirectory = fileManager.temporaryDirectory.appendingPathComponent("ClaudexMacOS", isDirectory: true)
        try fileManager.createDirectory(at: scriptDirectory, withIntermediateDirectories: true)
        let scriptURL = scriptDirectory.appendingPathComponent(UUID().uuidString + ".command")
        let script = Self.script(
            executable: executable,
            arguments: adapter.arguments(for: conversation, action: action),
            projectPath: conversation.projectPath
        )
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([scriptURL], withApplicationAt: terminalURL, configuration: configuration) { _, error in
            if let error { NSLog("claudex-macos failed to open Terminal: %@", error.localizedDescription) }
        }
    }

    func findExecutable(named name: String) -> String? {
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let locations = environmentPath.split(separator: ":").map(String.init)
            + [NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        for directory in locations {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if fileManager.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    static func script(executable: String, arguments: [String], projectPath: String) -> String {
        let command = ([executable] + arguments).map(shellQuoted).joined(separator: " ")
        return "#!/bin/zsh\ncd -- \(shellQuoted(projectPath)) || exit 1\nexec \(command)\n"
    }

    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
