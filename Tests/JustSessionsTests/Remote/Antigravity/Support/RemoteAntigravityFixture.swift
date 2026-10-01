import Foundation
@testable import JustSessions

struct RemoteAntigravityFixture {
    let root: URL
    let home: URL
    let session: AntigravitySessionFixture
    let conversation: Conversation
    let binaryDirectory: URL

    init() throws {
        root = try makeTemporaryDirectory()
        home = root.appendingPathComponent("remote home")
        session = try AntigravitySessionFixture(configurationDirectory: home.appendingPathComponent(".gemini/antigravity-cli"))
        try session.writeIndex()
        let mirror = root.appendingPathComponent("mirror/antigravity")
        try AntigravitySQLiteSnapshot.copySessionStore(at: session.configurationDirectory, to: mirror)
        conversation = .fixture(provider: .antigravity, sessionID: session.sessionID, projectPath: session.projectPath,
                                sourceFile: mirror.appendingPathComponent("conversations/\(session.sessionID).db"), host: .ssh("devbox"))
        binaryDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: binaryDirectory.appendingPathComponent("login-shell"))
    }

    func runner(lsofExitStatus: Int = 1) throws -> RemoteHostCommandRunner {
        try writeExecutableScript("#!/bin/sh\nexit \(lsofExitStatus)\n", to: binaryDirectory.appendingPathComponent("lsof"))
        return RemoteHostCommandRunner { _, command, _ in
            BoundedProcessRunner.result(ofExecutable: "/bin/sh", arguments: ["-c", command],
                environment: ["HOME": home.path, "SHELL": binaryDirectory.appendingPathComponent("login-shell").path,
                              "PATH": binaryDirectory.path + ":/usr/bin:/bin"], includesStandardError: true, timeout: 20)
        }
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
