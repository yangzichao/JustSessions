import Foundation

final class RemoteClaudeSessionIDFlagSupport: @unchecked Sendable {
    static let shared = RemoteClaudeSessionIDFlagSupport()

    private let runner: RemoteHostCommandRunner
    private let helpTimeout: TimeInterval
    private let lock = NSLock()
    private var answersByCheck: [String: Bool] = [:]
    private var checksRunning: Set<String> = []

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner(cancelsWithTask: true), helpTimeout: TimeInterval = 30) {
        self.runner = runner
        self.helpTimeout = helpTimeout
    }

    func preassignedSessionID(host: String, startCommand: String?) -> String? {
        guard lock.withLock({ answersByCheck[Self.key(host: host, startCommand: startCommand)] }) == true else { return nil }
        // Claude Code's own ids are lowercase, and it names the transcript by the id exactly as given.
        return UUID().uuidString.lowercased()
    }

    @discardableResult
    func checkInBackgroundIfUnanswered(host: String, startCommand: String?) -> Task<Void, Never>? {
        let key = Self.key(host: host, startCommand: startCommand)
        let startsCheck = lock.withLock {
            answersByCheck[key] == nil && checksRunning.insert(key).inserted
        }
        guard startsCheck else { return nil }
        return Task.detached(priority: .utility) { [self] in _ = check(host: host, startCommand: startCommand) }
    }

    @discardableResult
    func check(host: String, startCommand: String?) -> Bool? {
        let result = runner.run(host, Self.helpCommand(startCommand: startCommand, host: host), helpTimeout)
        let answer = result.flatMap { $0.exitStatus == 0 ? ClaudeSessionIDFlagSupport.helpTextListsFlag($0.output) : nil }
        let key = Self.key(host: host, startCommand: startCommand)
        lock.withLock {
            checksRunning.remove(key)
            if let answer, !Task.isCancelled { answersByCheck[key] = answer }
        }
        return answer
    }

    static func helpCommand(
        startCommand: String?,
        host: String,
        cliLocation: RemoteCLILocation? = nil
    ) -> String {
        let invocation =
            CLIStartCommandLine.customCommand(startCommand).map {
                CLIStartCommandLine.remoteInvocation(startCommand: $0, arguments: ["--help"])
            } ?? RemoteCLIInvocation.oneOffInvocation(
                executableName: ConversationProvider.claude.executableName,
                location: cliLocation ?? RemoteHostCLILocations.shared.location(of: .claude, on: host)
            ) + " --help"
        return RemoteCLICommandBuilder.loginShellCommand(invocation, on: host)
    }

    private static func key(host: String, startCommand: String?) -> String {
        [host, CLIStartCommandLine.customCommand(startCommand) ?? ""].joined(separator: "\u{0}")
    }
}
