import Foundation
import Testing

@testable import JustSessions

/// Kiro CLI V3 sessions on an SSH host: copied beside V2's, with only their metadata and log, and deleted there.
struct KiroV3RemoteTests {
    private struct Host {
        let root: URL
        let remoteHome: URL
        let projectDirectory: URL
        let mirror: RemoteSessionMirror
        var sessionsRoot: URL { remoteHome.appendingPathComponent(".kiro/sessions") }

        init() throws {
            root = try makeTemporaryDirectory()
            remoteHome = root.appendingPathComponent("remote home")
            projectDirectory = root.appendingPathComponent("Bob's paper; $dollar")
            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
            mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: remoteHome.path)
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    @Test func aV3SessionIsCopiedWithItsMetadataAndLogAloneAndListedBesideV2() throws {
        let host = try Host()
        defer { host.remove() }
        let written = try KiroV3SessionFixture(sessionsRoot: host.sessionsRoot).writeSession(
            projectPath: host.projectDirectory.path,
            extraFiles: ["publish.cursor": "23730:14", "snapshots/a.json": "{}", "sub-executions/x/messages.jsonl": "{}\n"]
        )
        let classicID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: host.sessionsRoot.appendingPathComponent("cli")).writeSession(
            id: classicID, projectPath: host.projectDirectory.path, messageLines: KiroTranscriptSamples.lines
        )

        let conversations = try RemoteSessionDiscovery(mirror: host.mirror).discover(host: "devbox").filter { $0.provider == .kiro }

        #expect(Set(conversations.map(\.sessionID)) == [written.sessionID, classicID])
        let v3 = try #require(conversations.first { $0.sessionID == written.sessionID })
        #expect(v3.host == .ssh("devbox"))
        #expect(v3.suggestedTitle == "Fix the build")
        let copiedFolder = v3.sourceFile.deletingLastPathComponent()
        #expect(
            Set(try FileManager.default.contentsOfDirectory(atPath: copiedFolder.path))
                == [KiroV3Session.metadataFileName, KiroV3Session.messagesFileName])
        #expect(
            !FileManager.default.fileExists(atPath: host.mirror.kiroV3MirrorDirectory(host: "devbox").appendingPathComponent("cli").path))
        let transcript = try KiroTranscriptReader().read(v3.sourceFile)
        #expect(transcript.entries.first?.content == .userMessage("Fix the build"))
    }

    @Test func aV3SessionDeletedOnTheHostLeavesTheCopy() throws {
        let host = try Host()
        defer { host.remove() }
        let written = try KiroV3SessionFixture(sessionsRoot: host.sessionsRoot).writeSession(projectPath: host.projectDirectory.path)
        let discovery = RemoteSessionDiscovery(mirror: host.mirror)
        #expect(try discovery.discover(host: "devbox").contains { $0.sessionID == written.sessionID })

        try FileManager.default.removeItem(at: written.folder)

        #expect(try !discovery.discover(host: "devbox").contains { $0.sessionID == written.sessionID })
    }

    @Test func deletionRunsKiroInTheProjectThenDropsTheCopiedFolder() throws {
        let host = try Host()
        defer { host.remove() }
        let fixture = KiroV3SessionFixture(sessionsRoot: host.sessionsRoot)
        let selected = try fixture.writeSession(projectPath: host.projectDirectory.path)
        let kept = try fixture.writeSession(projectPath: host.projectDirectory.path)
        let conversation = try #require(
            try RemoteSessionDiscovery(mirror: host.mirror).discover(host: "devbox")
                .first { $0.sessionID == selected.sessionID })
        let reportFile = host.root.appendingPathComponent("report.txt")
        let runner = try Self.runner(
            host: host,
            script: KiroV3DeletionTests.successfulDeletionScript + "\n"
                + "printf '%s\\n' \"$@\" \"$KIRO_HOME\" \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n")

        try RemoteConversationDeletion(runner: runner, mirror: host.mirror).delete(conversation)

        let report = try String(contentsOf: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(
            Array(report.prefix(4)) == [
                "chat", "--delete-session", selected.sessionID, host.remoteHome.appendingPathComponent(".kiro").path,
            ])
        #expect(
            URL(fileURLWithPath: try #require(report.last)).resolvingSymlinksInPath().path
                == host.projectDirectory.resolvingSymlinksInPath().path)
        #expect(!FileManager.default.fileExists(atPath: selected.folder.path))
        #expect(FileManager.default.fileExists(atPath: kept.folder.path))
        #expect(!FileManager.default.fileExists(atPath: conversation.sourceFile.deletingLastPathComponent().path))
    }

    @Test func aCLIThatLeavesTheFolderOnTheHostKeepsTheCopy() throws {
        let host = try Host()
        defer { host.remove() }
        let selected = try KiroV3SessionFixture(sessionsRoot: host.sessionsRoot).writeSession(projectPath: host.projectDirectory.path)
        let conversation = try #require(
            try RemoteSessionDiscovery(mirror: host.mirror).discover(host: "devbox")
                .first { $0.sessionID == selected.sessionID })

        let deletion = RemoteConversationDeletion(runner: try Self.runner(host: host, script: "#!/bin/sh\nexit 0\n"), mirror: host.mirror)
        #expect(throws: RemoteConversationDeletionError.self) { try deletion.delete(conversation) }

        #expect(FileManager.default.fileExists(atPath: selected.folder.path))
        #expect(FileManager.default.fileExists(atPath: conversation.sourceFile.path))
    }

    @Test func aV3SessionARunningCLIHoldsOnTheHostIsNotHandedToKiroAndAnEndedOnesPromptsGoWithIt() throws {
        let host = try Host()
        defer { host.remove() }
        let fixture = KiroV3SessionFixture(sessionsRoot: host.sessionsRoot)
        let held = try fixture.writeSession(projectPath: host.projectDirectory.path)
        let ended = try fixture.writeSession(projectPath: host.projectDirectory.path)
        try KiroSessionLockTests.writeLock(
            processID: getpid(), startedAt: .now, fractionalDigits: 3,
            to: held.folder.appendingPathComponent(".lock"))
        let history = host.sessionsRoot.appendingPathComponent("cli/\(ended.sessionID).history")
        try FileManager.default.createDirectory(at: history.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "Reply with exactly LOCK.\n".write(to: history, atomically: true, encoding: .utf8)
        let conversations = try RemoteSessionDiscovery(mirror: host.mirror).discover(host: "devbox")
        let deletion = RemoteConversationDeletion(
            runner: try Self.runner(host: host, script: KiroV3DeletionTests.successfulDeletionScript),
            mirror: host.mirror)

        let heldConversation = try #require(conversations.first { $0.sessionID == held.sessionID })
        let endedConversation = try #require(conversations.first { $0.sessionID == ended.sessionID })

        #expect(throws: RemoteConversationDeletionError.self) { try deletion.delete(heldConversation) }
        try deletion.delete(endedConversation)

        #expect(FileManager.default.fileExists(atPath: held.messagesFile.path))
        #expect(!FileManager.default.fileExists(atPath: ended.folder.path))
        #expect(!FileManager.default.fileExists(atPath: history.path))
    }

    /// Runs the host's command in `sh` with the stand-in home and a stand-in `kiro-cli` running `script`.
    private static func runner(host: Host, script: String) throws -> RemoteHostCommandRunner {
        let binaryDirectory = host.root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: binaryDirectory.appendingPathComponent("login-shell"))
        try writeExecutableScript(script, to: binaryDirectory.appendingPathComponent("kiro-cli"))
        let environment = [
            "HOME": host.remoteHome.path,
            "SHELL": binaryDirectory.appendingPathComponent("login-shell").path,
            "PATH": binaryDirectory.path + ":/usr/bin:/bin",
        ]
        return RemoteHostCommandRunner { _, command, _ in
            BoundedProcessRunner.result(
                ofExecutable: "/bin/sh", arguments: ["-c", command], environment: environment,
                includesStandardError: true, timeout: 10)
        }
    }
}
