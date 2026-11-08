import Foundation

/// Runs one command on a remote host without a terminal, failing instead of asking for a password. A host logged in to
/// with Connect… is reached through that login; see `SSHLoginConnections`. A host that couldn't be reached a moment
/// ago fails again at once, without connecting; see `SSHHostReachability`.
struct RemoteHostCommandRunner: Sendable {
    /// Replaces `ssh`, so tests can run the command in a local shell.
    let run: @Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32, output: String)?

    init(
        connectionSharingOptions: [String] = [],
        reachability: SSHHostReachability = .shared,
        cancelsWithTask: Bool = false,
        run: (@Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32, output: String)?)? = nil
    ) {
        self.run = run ?? { host, command, timeout in
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

    /// The `ssh` options of every connection made without a terminal, the `rsync` copies' included. A host that
    /// does not answer fails within 10 seconds, and a connection that dies, as when the Mac sleeps, within about
    /// 30 seconds instead of hanging until the command's timeout; a shorter network stall does not end it.
    /// Settings in `~/.ssh/config` meant for logging in by hand are turned off: with a `RemoteCommand`, `ssh` refuses
    /// to run the app's command, and port forwards clash with an open tab's, or fail the connection when
    /// `ExitOnForwardFailure` is set.
    static let nonInteractiveSSHOptions = ["-o", "BatchMode=yes"] + connectionSettingOptions

    /// The options above but `BatchMode`, which Connect…'s login leaves off so `ssh` can ask its questions.
    static let connectionSettingOptions = [
        "-o", "ConnectTimeout=10",
        "-o", "ServerAliveInterval=10",
        "-o", "ServerAliveCountMax=3",
        "-o", "RemoteCommand=none",
        "-o", "ClearAllForwardings=yes",
    ]

    /// `-T` keeps a `RequestTTY force` in `~/.ssh/config` from giving the command a terminal, which would change
    /// what passes through it, such as `rsync`'s transfer.
    static let noTerminalOption = "-T"

    static func sshArguments(host: String, command: String) -> [String] {
        sshArguments(host: host, command: command, connectionSharingOptions: [])
    }

    static func sshArguments(host: String, command: String, connectionSharingOptions: [String]) -> [String] {
        [noTerminalOption] + nonInteractiveSSHOptions + connectionSharingOptions + [host, command]
    }

    /// `ssh` exits with this when it could not connect or authenticate.
    static let connectionFailureExitStatus: Int32 = 255
}
