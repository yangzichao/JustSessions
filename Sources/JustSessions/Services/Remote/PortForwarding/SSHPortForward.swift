import Foundation

struct SSHPortForward: Hashable, Sendable {
    static let validPorts = 1...65535

    let host: String
    let localPort: Int
    let remotePort: Int

    var address: String { "localhost:\(localPort)" }

    var browserURL: URL? { URL(string: "http://localhost:\(localPort)") }

    var sshLocalForwardArgument: String { "127.0.0.1:\(localPort):localhost:\(remotePort)" }
}

/// The `ssh` commands of port forwarding. Forwards are added to a running connection one by one with `-O forward`, from
/// an `ssh` that reads no config (`-F /dev/null`), so neither it nor the connection, which is made with
/// `ClearAllForwardings=yes`, starts the `LocalForward` lines of the user's `~/.ssh/config`: an open tab holds those
/// ports, and the forward would fail for them.
enum SSHPortForwardCommands {
    enum Request: String {
        case forward
        case cancel
    }

    static func connectionArguments(host: String, controlPath: String) -> [String] {
        ["-N", RemoteHostCommandRunner.noTerminalOption]
            + RemoteHostCommandRunner.nonInteractiveSSHOptions
            + [
                "-o", "ExitOnForwardFailure=no",
                "-o", "ControlMaster=yes",
                "-o", "ControlPath=\(controlPath)",
                "-o", "ControlPersist=no",
                "--", host,
            ]
    }

    static func requestArguments(_ request: Request, _ forward: SSHPortForward, controlPath: String) -> [String] {
        [
            "-F", "/dev/null", "-o", "BatchMode=yes", "-S", controlPath,
            "-O", request.rawValue, "-L", forward.sshLocalForwardArgument, "--", forward.host,
        ]
    }

    /// Opens one connection to the forward's port on the host, as a program on this Mac would through the forward,
    /// and closes it at once; a host that refuses forwarding refuses it.
    static func probeArguments(_ forward: SSHPortForward, controlPath: String) -> [String] {
        [
            "-F", "/dev/null", "-o", "BatchMode=yes", "-S", controlPath,
            "-W", "localhost:\(forward.remotePort)", "--", forward.host,
        ]
    }
}
