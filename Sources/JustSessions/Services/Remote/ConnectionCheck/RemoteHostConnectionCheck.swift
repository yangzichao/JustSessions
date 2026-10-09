import Foundation

/// Logs in to a host the way the app's background commands do, before the host is added, so the Add SSH host sheet
/// can say what is wrong while it is still open.
struct RemoteHostConnectionCheck: Sendable {
    let runner: RemoteHostCommandRunner

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        self.runner = runner
    }

    /// Longer than `ConnectTimeout`, with time left for a slow login; see `RemoteHostCommandRunner`.
    static let timeout: TimeInterval = 20

    /// Nil when the host accepted the login. Only `ssh`'s own exit status counts as a failure, so a host whose shell
    /// startup prints errors still passes.
    func problem(connectingTo host: String) -> SSHConnectionProblem? {
        guard let result = runner.run(host, "true", Self.timeout) else { return .noAnswer }
        guard result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus else { return nil }
        return SSHConnectionProblem(sshOutput: result.output)
    }
}
