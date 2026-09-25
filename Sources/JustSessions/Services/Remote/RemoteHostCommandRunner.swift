import Foundation

/// Runs one command on a remote host without a terminal, failing instead of asking for a password.
struct RemoteHostCommandRunner: Sendable {
    /// Replaces `ssh`, so tests can run the command in a local shell.
    let run: @Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32, output: String)?

    init(run: (@Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32, output: String)?)? = nil) {
        self.run = run ?? { host, command, timeout in
            BoundedProcessRunner.result(
                ofExecutable: "/usr/bin/ssh",
                arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, command],
                includesStandardError: true,
                timeout: timeout
            )
        }
    }

    /// `ssh` exits with this when it could not connect or authenticate.
    static let connectionFailureExitStatus: Int32 = 255
}
