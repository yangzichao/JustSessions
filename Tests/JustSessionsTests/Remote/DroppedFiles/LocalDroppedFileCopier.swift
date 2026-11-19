import Foundation

@testable import JustSessions

extension RemoteDroppedFileCopier {
    static func local(home: URL, shell: String = "/bin/sh", firstCommands: String = "") -> RemoteDroppedFileCopier {
        RemoteDroppedFileCopier { _, hostCommand, _ in
            ProcessLaunch(
                executablePath: shell,
                arguments: ["-c", firstCommands + hostCommand],
                environment: ["HOME": home.path, "PATH": "/usr/bin:/bin"]
            )
        }
    }

    static func replacingSSH(with script: String) -> RemoteDroppedFileCopier {
        RemoteDroppedFileCopier { _, _, _ in
            ProcessLaunch(executablePath: "/bin/sh", arguments: ["-c", script], environment: ["PATH": "/usr/bin:/bin"])
        }
    }
}

func makeDroppedFile(named name: String, byteCount: Int, in folder: URL) throws -> URL {
    let file = folder.appendingPathComponent(name)
    try Data((0..<byteCount).map { UInt8(truncatingIfNeeded: $0 &* 31) }).write(to: file)
    return file
}
