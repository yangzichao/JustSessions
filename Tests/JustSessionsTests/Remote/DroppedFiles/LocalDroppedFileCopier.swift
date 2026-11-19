import Foundation

@testable import JustSessions

extension RemoteDroppedFileCopier {
    /// Runs the host's command in a local `shell` whose home folder is `home`, standing in for the host's, after
    /// `firstCommands`, such as a delay.
    static func local(home: URL, shell: String = "/bin/sh", firstCommands: String = "") -> RemoteDroppedFileCopier {
        RemoteDroppedFileCopier { _, hostCommand, _ in
            ProcessLaunch(
                executablePath: shell,
                arguments: ["-c", firstCommands + hostCommand],
                environment: ["HOME": home.path, "PATH": "/usr/bin:/bin"]
            )
        }
    }

    /// Runs `script` in place of `ssh` and the host's command, as a failing connection or host does.
    static func replacingSSH(with script: String) -> RemoteDroppedFileCopier {
        RemoteDroppedFileCopier { _, _, _ in
            ProcessLaunch(executablePath: "/bin/sh", arguments: ["-c", script], environment: ["PATH": "/usr/bin:/bin"])
        }
    }
}

/// A file of `byteCount` bytes that aren't all the same, named `name` in `folder`.
func makeDroppedFile(named name: String, byteCount: Int, in folder: URL) throws -> URL {
    let file = folder.appendingPathComponent(name)
    try Data((0..<byteCount).map { UInt8(truncatingIfNeeded: $0 &* 31) }).write(to: file)
    return file
}
