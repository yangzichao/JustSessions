import Foundation

/// Runs one command on a remote host without a terminal, failing instead of asking for a password.
struct RemoteHostCommandRunner: Sendable {
    /// Replaces `ssh`, so tests can run the command in a local shell.
    let run: @Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32, output: String)?

    init(run: (@Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32, output: String)?)? = nil) {
        self.run = run ?? { host, command, timeout in
            BoundedProcessRunner.result(
                ofExecutable: "/usr/bin/ssh",
                arguments: Self.sshArguments(host: host, command: command),
                includesStandardError: true,
                timeout: timeout
            )
        }
    }

    /// The `ssh` options of every connection made without a terminal, the `rsync` copies' included. A host that
    /// does not answer fails within 10 seconds, and a connection that dies, as when the Mac sleeps, within about
    /// 15 seconds instead of hanging until the command's timeout.
    static let nonInteractiveSSHOptions = [
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=10",
        "-o", "ServerAliveInterval=5",
        "-o", "ServerAliveCountMax=3",
    ]

    static func sshArguments(host: String, command: String) -> [String] {
        nonInteractiveSSHOptions + [host, command]
    }

    /// `ssh` exits with this when it could not connect or authenticate.
    static let connectionFailureExitStatus: Int32 = 255
}
