import Darwin
import Foundation

/// Lets a host's background commands and copies share one SSH connection. A refresh then logs in once instead of
/// about nine times, so a key that asks for Touch ID or a tap asks once, and a slow login, as through a jump host, is
/// paid once. The first command's `ssh` keeps the connection open in the background for `idleSeconds` after the
/// last one ends. A host whose `~/.ssh/config` sets a `ControlPath` keeps the user's own settings. Tabs don't share:
/// each keeps a connection of its own, so ending one connection never ends the others' CLIs.
enum SSHConnectionSharing {
    static let idleSeconds = 60

    /// `%C` is a hash of this Mac, the host, its port, and the user, so each host's connection has its own socket.
    /// A Unix socket path has room for about 100 bytes, and `ssh` adds 17 while it sets the socket up, so the
    /// folder is in `/tmp`; the per-user `TMPDIR` is too long.
    static let socketDirectory = "/tmp/justsessions-ssh-\(getuid())"

    /// The options for the host's background commands. None when the user's config sets a `ControlPath`, or when
    /// the socket folder can't be used safely.
    static func options(for host: String) -> [String] {
        options(
            userControlPath: SSHHostConfiguration.resolve(host: host)?.controlPath,
            socketDirectory: SSHSocketDirectory.prepared(at: socketDirectory)
        )
    }

    static func options(userControlPath: String?, socketDirectory: String?) -> [String] {
        guard userControlPath == nil, let socketDirectory else { return [] }
        return [
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=\(socketDirectory)/%C",
            "-o", "ControlPersist=\(idleSeconds)",
        ]
    }

    /// Ends the host's shared connection, as when the host is removed; nothing happens when there is none.
    static func closeSharedConnection(to host: String) {
        let sharingOptions = options(for: host)
        guard !sharingOptions.isEmpty else { return }
        _ = BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/ssh",
            arguments: ["-O", "exit", "-o", "BatchMode=yes"] + sharingOptions + ["--", host],
            environment: SSHProcessEnvironment.standard,
            includesStandardError: true,
            timeout: 10
        )
    }
}
