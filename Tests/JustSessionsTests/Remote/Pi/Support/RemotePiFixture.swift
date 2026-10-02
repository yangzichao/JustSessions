import Foundation
@testable import JustSessions

/// A temporary folder standing in for an SSH host's home, with one Pi session in `~/.pi/agent/sessions` and its copy
/// in that host's Pi mirror. The project folder's name has spaces, quotes, and shell syntax in it.
struct RemotePiFixture {
    static let projectFolderName = #"--home-me-Bob's "paper"; $HOME `x`--"#

    let root: URL
    let remoteHome: URL
    let sessionsDirectory: URL
    let hostProjectFolder: PiSessionFolderFixture
    let hostSessionFile: URL
    let mirror: RemoteSessionMirror
    let conversation: Conversation

    init() throws {
        root = try makeTemporaryDirectory()
        remoteHome = root.appendingPathComponent("remote home")
        sessionsDirectory = remoteHome.appendingPathComponent(".pi/agent/sessions")
        hostProjectFolder = PiSessionFolderFixture(sessionsDirectory: sessionsDirectory.appendingPathComponent(Self.projectFolderName))
        let sessionID = UUID().uuidString.lowercased()
        hostSessionFile = try hostProjectFolder.writeSession(
            id: sessionID,
            projectPath: "/home/me/paper",
            lines: [PiSessionFolderFixture.userMessage("Fix the build")],
            inProjectFolder: false
        )
        mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"))
        let mirrorProjectFolder = mirror.mirrorDirectory(host: "devbox", provider: .pi).appendingPathComponent(Self.projectFolderName)
        try FileManager.default.createDirectory(at: mirrorProjectFolder, withIntermediateDirectories: true)
        let mirrorFile = mirrorProjectFolder.appendingPathComponent(hostSessionFile.lastPathComponent)
        try FileManager.default.copyItem(at: hostSessionFile, to: mirrorFile)
        conversation = .fixture(provider: .pi, sessionID: sessionID, projectPath: "/home/me/paper", sourceFile: mirrorFile, host: .ssh("devbox"))
    }

    /// The folder beside the session file on the host, where Pi extensions keep subagent runs and forks.
    var hostCompanionFolder: URL {
        hostSessionFile.deletingPathExtension()
    }

    /// Deletes through `/bin/sh` with the temporary home as `$HOME`, the way `ssh devbox <command>` would run it.
    func deletion() -> RemoteConversationDeletion {
        RemoteConversationDeletion(runner: RemoteHostCommandRunner { [self] _, command, _ in runOnHost(command) }, mirror: mirror)
    }

    /// Runs a command through `/bin/sh` with the temporary home as `$HOME`.
    func runOnHost(_ command: String) -> (exitStatus: Int32, output: String)? {
        BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", command],
            environment: ["HOME": remoteHome.path, "PATH": "/usr/bin:/bin"],
            includesStandardError: true,
            timeout: 20
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
