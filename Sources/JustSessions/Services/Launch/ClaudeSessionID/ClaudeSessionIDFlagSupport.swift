import Foundation

/// Whether an installed `claude` accepts `--session-id <uuid>` for a new session. With the flag the app
/// knows a new tab's session id before the CLI writes anything, so linking the tab does not depend on
/// process ids or registry files. An older or wrapped install could reject an unknown flag and fail to
/// start, so the flag is only passed once the executable's `--help` lists it.
final class ClaudeSessionIDFlagSupport: @unchecked Sendable {
    static let shared = ClaudeSessionIDFlagSupport()
    static let flag = "--session-id"

    private let helpTimeout: TimeInterval
    private let lock = NSLock()
    private var answersByExecutablePath: [String: Bool] = [:]
    private var executablePathsBeingChecked: Set<String> = []

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

    /// Runs `<claude> --help` and records whether it lists the flag. Returns nil when the check could not
    /// finish, so a later launch tries again.
    @discardableResult
    func check(_ command: NativeCLICommand) -> Bool? {
        let helpText = BoundedProcessRunner.output(
            ofExecutable: command.executablePath,
            arguments: ["--help"],
            environment: command.environmentVariables,
            includesStandardError: true,
            timeout: helpTimeout
        )
        let answer = helpText.map(Self.helpTextListsFlag)
        lock.withLock {
            executablePathsBeingChecked.remove(command.executablePath)
            if let answer { answersByExecutablePath[command.executablePath] = answer }
        }
        return answer
    }

    static func helpTextListsFlag(_ helpText: String) -> Bool {
        helpText
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .contains { $0 == flag || $0.hasPrefix("\(flag)=") }
    }

    private func isKnownToAcceptFlag(_ command: NativeCLICommand) -> Bool {
        if let answer = lock.withLock({ answersByExecutablePath[command.executablePath] }) { return answer }
        if beginCheckIfUnanswered(command) {
            Task.detached(priority: .utility) { [self] in check(command) }
        }
        return false
    }

    /// Marks the executable as being checked; false when it already has an answer or a running check.
    private func beginCheckIfUnanswered(_ command: NativeCLICommand) -> Bool {
        lock.withLock {
            guard answersByExecutablePath[command.executablePath] == nil else { return false }
            return executablePathsBeingChecked.insert(command.executablePath).inserted
        }
    }
}
