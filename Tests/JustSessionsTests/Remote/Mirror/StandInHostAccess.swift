import Foundation

@testable import JustSessions

/// A folder on this Mac stands in for an SSH host's home: commands run in a local `sh` with that home and a fake
/// login shell, and `rsync` reaches it through a fake `ssh` that runs rsync's other end here, in the home.
extension RemoteMirrorHostAccess {
    static func standIn(home: String) -> RemoteMirrorHostAccess {
        let scripts = StandInHostScripts.directory
        let environment = [
            "HOME": home, "SHELL": scripts.appendingPathComponent("login-shell").path, "PATH": "/usr/bin:/bin",
        ]
        return RemoteMirrorHostAccess(
            connectionSharing: { _ in nil },
            commandRunner: { _ in
                RemoteHostCommandRunner { _, command, timeout in
                    BoundedProcessRunner.result(
                        ofExecutable: "/bin/sh", arguments: ["-c", command], environment: environment,
                        includesStandardError: true, timeout: timeout, cancelsWithTask: true)
                }
            },
            rsyncRemoteShell: { _ in
                RemoteSessionMirror.rsyncRemoteShellCommand([
                    "/usr/bin/env", "HOME=\(home)", scripts.appendingPathComponent("ssh").path,
                ])
            }
        )
    }
}

private enum StandInHostScripts {
    static let directory: URL = {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("justsessions-stand-in-host-\(getpid())")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try? writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: directory.appendingPathComponent("login-shell"))
        _ = try? writeExecutableScript(
            "#!/bin/sh\nshift\ncd \"$HOME\" || exit 1\nexec /bin/sh -c \"$*\"\n", to: directory.appendingPathComponent("ssh"))
        return directory
    }()
}
