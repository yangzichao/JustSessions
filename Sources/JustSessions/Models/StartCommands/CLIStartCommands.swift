import Foundation

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

    func customCommand(for provider: ConversationProvider, on host: SessionHost) -> String? {
        commandsByHostAndTool[Self.storageKey(provider: provider, host: host)]
    }

    mutating func setCommand(_ proposedCommand: String, for provider: ConversationProvider, on host: SessionHost) {
        let command = Self.normalizedCommand(proposedCommand)
        let key = Self.storageKey(provider: provider, host: host)
        if Self.startsAsTheAppDoes(command, provider: provider) {
            commandsByHostAndTool.removeValue(forKey: key)
        } else {
            commandsByHostAndTool[key] = command
        }
    }

    static func startsAsTheAppDoes(_ command: String, provider: ConversationProvider) -> Bool {
        command.isEmpty || command == provider.executableName || command == provider.defaultStartCommand
    }

    static func normalizedCommand(_ proposedCommand: String) -> String {
        proposedCommand
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func storageKey(provider: ConversationProvider, host: SessionHost) -> String {
        switch host {
        case .thisMac: "\(provider.executableName)@this-mac"
        case .ssh(let destination): "\(provider.executableName)@ssh:\(destination)"
        }
    }
}
