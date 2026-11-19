import Foundation

extension ConversationStore {
    func customStartCommand(for provider: ConversationProvider, on host: SessionHost) -> String? {
        cliStartCommands.customCommand(for: provider, on: host)
    }

    func saveStartCommand(
        _ proposedCommand: String,
        for provider: ConversationProvider,
        on host: SessionHost,
        check: StartCommandCheck? = nil
    ) async throws {
        let command = CLIStartCommands.normalizedCommand(proposedCommand)
        if !CLIStartCommands.startsAsTheAppDoes(command, provider: provider) {
            let check = check ?? StartCommandCheck(resolver: commandResolver)
            try await Task.detached(priority: .userInitiated) { try check.check(command, on: host) }.value
        }
        setStartCommand(command, for: provider, on: host)
    }

    func setStartCommand(_ proposedCommand: String, for provider: ConversationProvider, on host: SessionHost) {
        var updatedCommands = cliStartCommands
        updatedCommands.setCommand(proposedCommand, for: provider, on: host)
        guard updatedCommands != cliStartCommands else { return }
        cliStartCommands = updatedCommands
        cliStartCommands.save(to: userDefaults)
    }
}
