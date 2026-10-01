import Foundation
@testable import JustSessions

struct RemoteKiroFixture {
    let root: URL
    let remoteHome: URL
    let sessionsDirectory: URL
    let projectDirectory: URL
    let binaryDirectory: URL
    let conversation: Conversation

    init() throws {
        root = try makeTemporaryDirectory()
        remoteHome = root.appendingPathComponent("remote home")
        sessionsDirectory = remoteHome.appendingPathComponent(".kiro/sessions/cli")
        projectDirectory = root.appendingPathComponent("Bob's paper; $dollar")
        binaryDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: binaryDirectory.appendingPathComponent("login-shell"))
        let sessionID = UUID().uuidString.lowercased()
        let sessionFixture = KiroSessionFolderFixture(sessionsDirectory: sessionsDirectory)
        try sessionFixture.writeSession(id: sessionID, projectPath: projectDirectory.path, messageLines: KiroTranscriptSamples.lines)
        let mirrorDirectory = root.appendingPathComponent("mirror/kiro")
        try FileManager.default.createDirectory(at: mirrorDirectory, withIntermediateDirectories: true)
        for fileExtension in ["json", "jsonl"] {
            let fileName = "\(sessionID).\(fileExtension)"
            try FileManager.default.copyItem(at: sessionsDirectory.appendingPathComponent(fileName), to: mirrorDirectory.appendingPathComponent(fileName))
        }
        conversation = .fixture(
            provider: .kiro,
            sessionID: sessionID,
            projectPath: projectDirectory.path,
            sourceFile: mirrorDirectory.appendingPathComponent("\(sessionID).jsonl"),
            host: .ssh("devbox")
        )
    }

    func runner(running script: String = KiroHomeFixture.successfulDeletionScript) throws -> RemoteHostCommandRunner {
        try writeExecutableScript(script, to: binaryDirectory.appendingPathComponent("kiro-cli"))
        let environment = [
            "HOME": remoteHome.path,
            "SHELL": binaryDirectory.appendingPathComponent("login-shell").path,
            "PATH": binaryDirectory.path + ":/usr/bin:/bin",
            "KIRO_HOME": root.appendingPathComponent("unmirrored-home").path,
        ]
        return RemoteHostCommandRunner { _, command, _ in
            BoundedProcessRunner.result(
                ofExecutable: "/bin/sh",
                arguments: ["-c", command],
                environment: environment,
                includesStandardError: true,
                timeout: 10
            )
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
