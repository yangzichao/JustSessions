import Foundation

struct RemoteHostCommandRunner: Sendable {
    let run: @Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32, output: String)?

    init(
        connectionSharingOptions: [String] = [],
        reachability: SSHHostReachability = .shared,
        cancelsWithTask: Bool = false,
        run: (@Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32, output: String)?)? = nil
    ) {
        self.run =
            run ?? { host, command, timeout in
                if cancelsWithTask, Task.isCancelled { return nil }
                if let failureOutput = reachability.recentFailureOutput(on: host) {
                    return (Self.connectionFailureExitStatus, failureOutput)
                }
                let result = BoundedProcessRunner.result(
                    ofExecutable: "/usr/bin/ssh",
                    arguments: Self.sshArguments(
                        host: host,
                        command: command,
                        connectionSharingOptions: connectionSharingOptions.isEmpty
                            ? SSHLoginConnections.shared.connectionOptions(for: host)
                            : connectionSharingOptions
                    ),
                    environment: SSHProcessEnvironment.standard,
                    includesStandardError: true,
                    timeout: timeout,
                    cancelsWithTask: cancelsWithTask
                )
                if let result { reachability.noteResult(exitStatus: result.exitStatus, output: result.output, on: host) }
                return result
            }
    }

    /// Settings in `~/.ssh/config` meant for logging in by hand are turned off: with a `RemoteCommand`, `ssh` refuses
    /// to run the app's command, and port forwards clash with an open tab's, or fail the connection when
    /// `ExitOnForwardFailure` is set.
    static let nonInteractiveSSHOptions = ["-o", "BatchMode=yes"] + connectionSettingOptions

    static let connectionSettingOptions =
        SSHConnectTimeout.options + [
            "-o", "ServerAliveInterval=10",
            "-o", "ServerAliveCountMax=3",
            "-o", "RemoteCommand=none",
            "-o", "ClearAllForwardings=yes",
        ]

    /// `-T` keeps a `RequestTTY force` in `~/.ssh/config` from giving the command a terminal, which would change
    /// what passes through it, such as `rsync`'s transfer.
    static let noTerminalOption = "-T"

    static func sshArguments(host: String, command: String, connectionSharingOptions: [String]) -> [String] {
        [noTerminalOption] + nonInteractiveSSHOptions + connectionSharingOptions + [host, command]
    }

    static let connectionFailureExitStatus: Int32 = 255
}
