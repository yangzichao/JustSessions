import Foundation

/// Whether an SSH host's `claude` accepts `--session-id <uuid>`, as `ClaudeSessionIDFlagSupport` asks on this Mac.
/// With the flag, a new tab knows its session before the CLI writes it, so it is never linked to another tab's
/// session or to one started outside the app; see `linkWaitingTabsToPreassignedSessions`. The host's `claude --help`
/// runs in its login shell, after a refresh found the CLI; a launch never waits for it and goes without the flag
/// until the answer is in. A start command of your own is checked on its own, since it can run another CLI.
final class RemoteClaudeSessionIDFlagSupport: @unchecked Sendable {
    static let shared = RemoteClaudeSessionIDFlagSupport()

    private let runner: RemoteHostCommandRunner
    private let helpTimeout: TimeInterval
    private let lock = NSLock()
    private var answersByCheck: [String: Bool] = [:]
    private var checksRunning: Set<String> = []

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner(), helpTimeout: TimeInterval = 30) {
        self.runner = runner
        self.helpTimeout = helpTimeout
    }

    /// A new session id when the host's CLI is known to accept the flag, and nil otherwise. Checks nothing.
    func preassignedSessionID(host: String, startCommand: String?) -> String? {
        guard lock.withLock({ answersByCheck[Self.key(host: host, startCommand: startCommand)] }) == true else { return nil }
        // Claude Code's own ids are lowercase, and it names the transcript by the id exactly as given.
        return UUID().uuidString.lowercased()
    }

    func checkInBackgroundIfUnanswered(host: String, startCommand: String?) {
        let key = Self.key(host: host, startCommand: startCommand)
        let startsCheck = lock.withLock {
            answersByCheck[key] == nil && checksRunning.insert(key).inserted
        }
        guard startsCheck else { return }
        Task.detached(priority: .utility) { [self] in check(host: host, startCommand: startCommand) }
    }

    /// Runs the CLI's `--help` on the host and records whether it lists the flag. Returns nil when it could not
    /// tell, as when the host is offline or the CLI fails, so a later refresh tries again.
    @discardableResult
    func check(host: String, startCommand: String?) -> Bool? {
        let result = runner.run(host, Self.helpCommand(startCommand: startCommand), helpTimeout)
        let answer = result.flatMap { $0.exitStatus == 0 ? ClaudeSessionIDFlagSupport.helpTextListsFlag($0.output) : nil }
        let key = Self.key(host: host, startCommand: startCommand)
        lock.withLock {
            checksRunning.remove(key)
            if let answer { answersByCheck[key] = answer }
        }
        return answer
    }

    /// What a new session's tab would start, with `--help` in place of the app's arguments.
    static func helpCommand(startCommand: String?) -> String {
        let invocation = CLIStartCommandLine.customCommand(startCommand).map {
            CLIStartCommandLine.remoteInvocation(startCommand: $0, arguments: ["--help"])
        } ?? "\(ConversationProvider.claude.executableName) --help"
        return RemoteCLICommandBuilder.loginShellCommand(invocation)
    }

    private static func key(host: String, startCommand: String?) -> String {
        [host, CLIStartCommandLine.customCommand(startCommand) ?? ""].joined(separator: "\u{0}")
    }
}
