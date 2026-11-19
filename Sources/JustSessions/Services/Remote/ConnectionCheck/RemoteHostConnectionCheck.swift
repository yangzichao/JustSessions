import Foundation

struct RemoteHostConnectionCheck: Sendable {
    let runner: RemoteHostCommandRunner

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        self.runner = runner
    }

    static let timeout = SSHConnectTimeout.plus(slowLoginAllowance)
    private static let slowLoginAllowance: TimeInterval = 10

    func problem(connectingTo host: String) -> SSHConnectionProblem? {
        guard let result = runner.run(host, WindowsHostProbe.command, Self.timeout) else { return .noAnswer }
        guard result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus else {
            return WindowsHostProbe.isWindows(output: result.output) ? .windowsHost : nil
        }
        return SSHConnectionProblem(sshOutput: result.output)
    }
}
