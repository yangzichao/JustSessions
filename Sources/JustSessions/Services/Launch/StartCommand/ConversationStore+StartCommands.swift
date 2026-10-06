import Foundation

/// The command each tool's CLI starts with on each host, set in the New session sheet. Every launch of the tool on
/// that host uses it: new sessions, resumes, branches, and reconnects.
extension ConversationStore {
    /// The command set for the tool on the host; nil when it starts as the app starts it.
    func customStartCommand(for provider: ConversationProvider, on host: SessionHost) -> String? {
        cliStartCommands.customCommand(for: provider, on: host)
    }

    /// From the New session sheet: checks the command where the tool runs before keeping it, and throws
    /// `StartCommandCheckError` instead of keeping one that would not start; see `StartCommandCheck`. Going back to
    /// the command the app uses needs no check.
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

    /// An empty command, or the one the app uses, goes back to that one; see `CLIStartCommands.setCommand`.
    func setStartCommand(_ proposedCommand: String, for provider: ConversationProvider, on host: SessionHost) {
        var updatedCommands = cliStartCommands
        updatedCommands.setCommand(proposedCommand, for: provider, on: host)
        guard updatedCommands != cliStartCommands else { return }
        cliStartCommands = updatedCommands
        cliStartCommands.save(to: userDefaults)
    }
}
