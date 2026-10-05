import Foundation

/// The command each tool's CLI starts with on each host, when it is not the one the app uses, `defaultStartCommand`:
/// a wrapper, another path, or the CLI with flags of your own, such as `~/bin/claude --dangerously-skip-permissions`
/// or `kiro-cli chat --trust-all-tools`. It is set in the New session sheet and starts new sessions, resumes, and
/// branches alike, for every tool. The app adds its own arguments after it, such as the session to resume.
struct CLIStartCommands: Equatable {
    static let userDefaultsKey = "cliStartCommands"

    private(set) var commandsByHostAndTool: [String: String]

    init(commandsByHostAndTool: [String: String] = [:]) {
        self.commandsByHostAndTool = commandsByHostAndTool
    }

    static func load(from userDefaults: UserDefaults) -> CLIStartCommands {
        let storedCommands = userDefaults.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
        return CLIStartCommands(commandsByHostAndTool: storedCommands)
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(commandsByHostAndTool, forKey: Self.userDefaultsKey)
    }

    /// The command set for the tool on the host; nil when it starts as the app starts it, see `defaultStartCommand`.
    func customCommand(for provider: ConversationProvider, on host: SessionHost) -> String? {
        commandsByHostAndTool[Self.storageKey(provider: provider, host: host)]
    }

    /// An empty command, the tool's executable name alone, or the command the app starts it with goes back to that
    /// command.
    mutating func setCommand(_ proposedCommand: String, for provider: ConversationProvider, on host: SessionHost) {
        let command = Self.normalizedCommand(proposedCommand)
        let key = Self.storageKey(provider: provider, host: host)
        if command.isEmpty || command == provider.executableName || command == provider.defaultStartCommand {
            commandsByHostAndTool.removeValue(forKey: key)
        } else {
            commandsByHostAndTool[key] = command
        }
    }

    /// One line, since the command is placed in a shell command line before the app's arguments.
    static func normalizedCommand(_ proposedCommand: String) -> String {
        proposedCommand
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// `claude@this-mac`, `codex@ssh:devbox`: the tool by its executable name, which never changes.
    private static func storageKey(provider: ConversationProvider, host: SessionHost) -> String {
        switch host {
        case .thisMac: "\(provider.executableName)@this-mac"
        case .ssh(let destination): "\(provider.executableName)@ssh:\(destination)"
        }
    }
}
