import Foundation

/// Whether an installed `claude` accepts `--session-id <uuid>` for a new session. With the flag the app
/// knows a new tab's session id before the CLI writes anything, so linking the tab does not depend on
/// process ids or registry files. An older or wrapped install could reject an unknown flag and fail to
/// start, so the flag is only passed once the executable's `--help` lists it. A start command of your own, see
/// `CLIStartCommands`, is checked with its own arguments, since they can pick another CLI or another version of it.
final class ClaudeSessionIDFlagSupport: @unchecked Sendable {
    static let shared = ClaudeSessionIDFlagSupport()
    static let flag = "--session-id"

    private let helpTimeout: TimeInterval
    private let lock = NSLock()
    private var answersByCommandLine: [String: Bool] = [:]
    private var commandLinesBeingChecked: Set<String> = []

    init(helpTimeout: TimeInterval = 10) {
        self.helpTimeout = helpTimeout
    }

    /// Adds `--session-id <new id>` when the executable is known to accept it. Never waits: an executable
    /// that has not been checked yet gets a background check, and this launch goes without the flag.
    func preassigningSessionID(to command: NativeCLICommand) -> (command: NativeCLICommand, sessionID: String)? {
        guard isKnownToAcceptFlag(command) else { return nil }
        // Claude Code's own ids are lowercase, and it names the transcript by the id exactly as given.
        let sessionID = UUID().uuidString.lowercased()
        return (command.appendingArguments([Self.flag, sessionID]), sessionID)
    }

    /// Checks the `claude` a new session would launch, so the first new session can already use the flag.
    func warmUpInBackground() {
        Task.detached(priority: .utility) { [self] in
            let resolver = NativeCLICommandResolver()
            guard let command = try? resolver.resolveNewSession(provider: .claude, projectPath: NSHomeDirectory()),
                  beginCheckIfUnanswered(command) else { return }
            check(command)
        }
    }

    /// Runs `<claude> <its arguments> --help` and records whether it lists the flag. Returns nil when the check
    /// could not finish, so a later launch tries again.
    @discardableResult
    func check(_ command: NativeCLICommand) -> Bool? {
        let helpText = BoundedProcessRunner.output(
            ofExecutable: command.executablePath,
            arguments: command.arguments + ["--help"],
            environment: command.environmentVariables,
            includesStandardError: true,
            timeout: helpTimeout
        )
        let answer = helpText.map(Self.helpTextListsFlag)
        let commandLine = Self.commandLine(of: command)
        lock.withLock {
            commandLinesBeingChecked.remove(commandLine)
            if let answer { answersByCommandLine[commandLine] = answer }
        }
        return answer
    }

    static func helpTextListsFlag(_ helpText: String) -> Bool {
        helpText
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .contains { $0 == flag || $0.hasPrefix("\(flag)=") }
    }

    private func isKnownToAcceptFlag(_ command: NativeCLICommand) -> Bool {
        if let answer = lock.withLock({ answersByCommandLine[Self.commandLine(of: command)] }) { return answer }
        if beginCheckIfUnanswered(command) {
            Task.detached(priority: .utility) { [self] in check(command) }
        }
        return false
    }

    /// Marks the command as being checked; false when it already has an answer or a running check.
    private func beginCheckIfUnanswered(_ command: NativeCLICommand) -> Bool {
        let commandLine = Self.commandLine(of: command)
        return lock.withLock {
            guard answersByCommandLine[commandLine] == nil else { return false }
            return commandLinesBeingChecked.insert(commandLine).inserted
        }
    }

    /// The executable and its arguments, which no argument can make ambiguous.
    private static func commandLine(of command: NativeCLICommand) -> String {
        ([command.executablePath] + command.arguments).joined(separator: "\u{0}")
    }
}
