import Foundation

@testable import JustSessions

struct RemotePiFixture {
    enum HostShell: String, CaseIterable {
        /// macOS's `/bin/sh`: bash in POSIX mode, which still accepts some bash-only syntax.
        case sh
        /// Debian's and Ubuntu's `/bin/sh`, which rejects syntax POSIX does not define.
        case dash

        var path: String {
            "/bin/\(rawValue)"
        }

        var isInstalled: Bool {
            FileManager.default.isExecutableFile(atPath: path)
        }

        static let installed = allCases.filter(\.isInstalled)
    }

    static let projectFolderName = #"--home-me-Bob's "paper"; $HOME `x`--"#

    let shell: HostShell
    let root: URL
    let hostBinDirectory: URL
    let remoteHome: URL
    let sessionsDirectory: URL
    let hostProjectFolder: PiSessionFolderFixture
    let hostSessionFile: URL
    let mirror: RemoteSessionMirror
    let conversation: Conversation

    init(shell: HostShell = .sh) throws {
        self.shell = shell
        root = try makeTemporaryDirectory()
        hostBinDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: hostBinDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: hostBinDirectory.appendingPathComponent("sh"),
            withDestinationURL: URL(fileURLWithPath: shell.path)
        )
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
        conversation = .fixture(
            provider: .pi, sessionID: sessionID, projectPath: "/home/me/paper", sourceFile: mirrorFile, host: .ssh("devbox"))
    }

    /// The folder beside the session file on the host, where Pi extensions keep subagent runs and forks.
    var hostCompanionFolder: URL {
        hostSessionFile.deletingPathExtension()
    }

    func deletion() -> RemoteConversationDeletion {
        RemoteConversationDeletion(runner: RemoteHostCommandRunner { [self] _, command, _ in runOnHost(command) }, mirror: mirror)
    }

    func runOnHost(_ command: String) -> (exitStatus: Int32, output: String)? {
        BoundedProcessRunner.result(
            ofExecutable: shell.path,
            arguments: ["-c", command],
            environment: ["HOME": remoteHome.path, "PATH": "\(hostBinDirectory.path):/usr/bin:/bin"],
            includesStandardError: true,
            timeout: 20
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
