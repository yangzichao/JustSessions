import Foundation
import Testing
@testable import JustSessions

struct OpenCodeRemoteMirrorTests {
    @Test func mirrorListsTopLevelSessionsWithTheirPreviewsButNoSecretsOrToolOutput() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        let database = fixture.hostDatabase
        try database.addSession("ses_archived00001", directory: RemoteOpenCodeFixture.projectPath, archivedAt: 1)
        try database.addMessage("msg_reply", session: OpenCodeDeletionFixture.retainedSessionID, createdAt: 2, data: ["role": "assistant"])
        try database.addPart("prt_reply1", message: "msg_reply", session: OpenCodeDeletionFixture.retainedSessionID, data: [
            "type": "tool", "tool": "bash",
            "state": ["status": "completed", "input": ["command": "cat .env"], "output": "secret-tool-output"],
        ])
        try database.addPart("prt_reply2", message: "msg_reply", session: OpenCodeDeletionFixture.retainedSessionID, data: [
            "type": "reasoning", "text": "secret-reasoning",
        ])
        try database.addPart("prt_reply3", message: "msg_reply", session: OpenCodeDeletionFixture.retainedSessionID, data: [
            "type": "file", "mime": "image/png", "url": "data:image/png;base64,secret-image-bytes",
        ])

        let conversations = try fixture.discovery.discover(host: "devbox")

        #expect(Set(conversations.map(\.sessionID)) == [OpenCodeDeletionFixture.selectedSessionID, OpenCodeDeletionFixture.retainedSessionID])
        #expect(conversations.allSatisfy { $0.host == .ssh("devbox") && $0.sourceFile == fixture.mirrorDatabase })
        let retained = try #require(conversations.first { $0.sessionID == OpenCodeDeletionFixture.retainedSessionID })
        #expect(retained.projectPath == RemoteOpenCodeFixture.projectPath)
        #expect(retained.suggestedTitle == "Keep me")
        #expect(try OpenCodeTranscriptReader().read(retained.sourceFile, sessionID: retained.sessionID).entries.map(\.content)
            == (try OpenCodeTranscriptReader().read(database.file, sessionID: retained.sessionID)).entries.map(\.content))
        let mirrored = String(decoding: try Data(contentsOf: fixture.mirrorDatabase), as: UTF8.self)
        for secret in ["secret-access-token", "secret-credential", "secret-tool-output", "secret-reasoning", "secret-image-bytes", "Subtask"] {
            #expect(!mirrored.contains(secret), "The mirror holds \(secret)")
        }
        #expect(mirrored.contains("cat .env"))
        let mirrorDirectory = fixture.mirrorDatabase.deletingLastPathComponent()
        #expect(try FileManager.default.contentsOfDirectory(atPath: mirrorDirectory.path) == ["opencode.db"])
    }

    @Test func pythonSnapshotOnTheHostBuildsTheSameMirror() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        try fixture.hostDatabase.addMessage("msg_reply", session: OpenCodeDeletionFixture.retainedSessionID, createdAt: 2, data: [
            "role": "assistant", "error": ["name": "APIError", "data": ["message": "Rate limited"]],
        ])
        try fixture.hostDatabase.addPart("prt_reply", message: "msg_reply", session: OpenCodeDeletionFixture.retainedSessionID, data: [
            "type": "tool", "tool": "read", "state": ["input": ["filePath": "/srv/a.swift"], "output": "secret-tool-output"],
        ])

        let result = try #require(fixture.runner().run("devbox", OpenCodeRemoteSnapshotCommand.create(on: "devbox"), 30))

        #expect(result.exitStatus == 0, "\(result.output)")
        let path = try #require(OpenCodeRemoteSnapshotCommand.snapshotPath(in: result.output))
        defer { try? FileManager.default.removeItem(atPath: path) }
        let snapshot = URL(fileURLWithPath: path).appendingPathComponent("opencode.db")
        let swiftSnapshot = fixture.root.appendingPathComponent("swift-snapshot.db")
        try OpenCodeSQLiteSnapshot.copy(fixture.hostDatabase.file, to: swiftSnapshot)
        #expect(try OpenCodeAdapter(databaseFile: snapshot).discover().map(\.sessionID).sorted()
            == [OpenCodeDeletionFixture.retainedSessionID, OpenCodeDeletionFixture.selectedSessionID])
        for sessionID in [OpenCodeDeletionFixture.retainedSessionID, OpenCodeDeletionFixture.selectedSessionID] {
            #expect(try OpenCodeTranscriptReader().read(snapshot, sessionID: sessionID).entries.map(\.content)
                == (try OpenCodeTranscriptReader().read(swiftSnapshot, sessionID: sessionID)).entries.map(\.content))
        }
        let mirrored = String(decoding: try Data(contentsOf: snapshot), as: UTF8.self)
        #expect(!mirrored.contains("secret-tool-output") && !mirrored.contains("secret-access-token"))
    }

    @Test func snapshotPathMustBeAFolderTheSnapshotMade() {
        #expect(OpenCodeRemoteSnapshotCommand.snapshotPath(in: "motd\nJUSTSESSIONS_OPENCODE_SNAPSHOT=/tmp/justsessions-opencode-ab_12") == "/tmp/justsessions-opencode-ab_12")
        #expect(OpenCodeRemoteSnapshotCommand.snapshotPath(in: "JUSTSESSIONS_OPENCODE_SNAPSHOT=/tmp/justsessions-opencode-../../home") == nil)
        #expect(OpenCodeRemoteSnapshotCommand.snapshotPath(in: "JUSTSESSIONS_OPENCODE_SNAPSHOT=/tmp/justsessions-opencode-x;rm -rf ~") == nil)
        #expect(OpenCodeRemoteSnapshotCommand.snapshotPath(in: "JUSTSESSIONS_OPENCODE_SNAPSHOT=/home/me") == nil)
        #expect(OpenCodeRemoteSnapshotCommand.snapshotPath(in: "") == nil)
    }

    @Test func aHostWithoutOpenCodeNeedsNoPythonAndLeavesNoMirror() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.hostDatabase.file)
        let destination = fixture.mirrorDatabase.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        // No python3 on this PATH: the command must stop before needing it.
        let runner = fixture.runner(environment: ["PATH": fixture.binaryDirectory.path + ":/bin"])

        let result = try #require(runner.run("devbox", OpenCodeRemoteSnapshotCommand.create(on: "devbox"), 30))
        try OpenCodeRemoteSessionMirror(runner: runner).synchronize(host: "devbox", sourceHomeOverride: nil, destination: destination)

        #expect(result.exitStatus == OpenCodeRemoteSnapshotCommand.noDatabaseExitStatus)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func aFailedSnapshotExplainsWhatTheHostNeeds() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        let recorder = RemoteCommandRecorder()
        let destination = fixture.mirrorDatabase.deletingLastPathComponent()

        #expect(throws: RemoteSessionMirrorError.self) {
            try OpenCodeRemoteSessionMirror(runner: recorder.runner(answering: (127, "python3: command not found")))
                .synchronize(host: "devbox", sourceHomeOverride: nil, destination: destination)
        }
        #expect(throws: RemoteSessionMirrorError.self) {
            try OpenCodeRemoteSessionMirror(runner: recorder.runner(answering: (0, "JUSTSESSIONS_OPENCODE_SNAPSHOT=/etc")))
                .synchronize(host: "devbox", sourceHomeOverride: nil, destination: destination)
        }
        // Neither attempt reached rsync or removed anything on the host.
        #expect(recorder.commands.count == 2)
    }

    @Test func aFailedConnectionSaysWhy() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        let runner = RemoteCommandRecorder().runner(answering: (255, "ssh: Could not resolve hostname devbox: nodename nor servname provided, or not known\n"))

        #expect(throws: RemoteSessionMirrorError.sshFailed(host: "devbox", problem: .hostNotFound)) {
            try OpenCodeRemoteSessionMirror(runner: runner)
                .synchronize(host: "devbox", sourceHomeOverride: nil, destination: fixture.mirrorDatabase.deletingLastPathComponent())
        }
        #expect(RemoteSessionMirrorError.sshFailed(host: "devbox", problem: .hostNotFound).errorDescription
            == "devbox couldn't be found. Check the host name and your network or VPN.")
    }

    @Test func theDatabaseLocationFollowsTheLoginShellsEnvironment() throws {
        let cases: [([String: String], String)] = [
            ([:], "/home/me/.local/share/opencode/opencode.db"),
            (["XDG_DATA_HOME": "/data"], "/data/opencode/opencode.db"),
            (["XDG_DATA_HOME": "relative"], "/home/me/.local/share/opencode/opencode.db"),
            (["OPENCODE_DB": "/tmp/oc.db", "XDG_DATA_HOME": "/data"], "/tmp/oc.db"),
            (["OPENCODE_DB": "oc.db"], "/home/me/.local/share/opencode/opencode.db"),
        ]
        for (environment, expectedPath) in cases {
            let output = BoundedProcessRunner.output(
                ofExecutable: "/bin/sh",
                arguments: ["-c", OpenCodeRemoteDatabaseLocation.shellAssignment + "\nprintf '%s' \"$db\""],
                environment: ["HOME": "/home/me", "PATH": "/usr/bin:/bin"].merging(environment) { $1 },
                timeout: 10
            )
            #expect(output == expectedPath, "\(environment)")
            #expect(OpenCodeAdapter.standardDatabaseFile(environment: environment, homeDirectory: "/home/me").path == expectedPath)
        }
    }

    @Test func databaseFromBeforeArchivingStillMirrors() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("opencode.db")
        try OpenCodeDatabaseFixture(file: source, createsTables: false).execute("""
            CREATE TABLE session (id TEXT PRIMARY KEY, parent_id TEXT, directory TEXT, title TEXT, time_updated INTEGER);
            CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT);
            CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT);
            INSERT INTO session VALUES ('ses_olderschema1', NULL, '/srv/app', 'Older', 1790000000000);
            INSERT INTO message VALUES ('msg_a', 'ses_olderschema1', 1, 1, '{"role":"user"}');
            INSERT INTO part VALUES ('prt_a', 'msg_a', 'ses_olderschema1', 1, 1, '{"type":"text","text":"Hello"}');
            """)
        let snapshot = root.appendingPathComponent("snapshot.db")

        try OpenCodeSQLiteSnapshot.copy(source, to: snapshot)

        #expect(try OpenCodeAdapter(databaseFile: snapshot).discover().map(\.sessionID) == ["ses_olderschema1"])
        #expect(try OpenCodeTranscriptReader().read(snapshot, sessionID: "ses_olderschema1").entries.map(\.content) == [.userMessage("Hello")])
    }

    @Test func deletedRemoteSessionsAndDatabasesDisappearFromTheNextMirror() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        #expect(try fixture.discovery.discover(host: "devbox").count == 2)

        try fixture.hostDatabase.execute("DELETE FROM session WHERE id = ?", [OpenCodeDeletionFixture.selectedSessionID])
        #expect(try fixture.discovery.discover(host: "devbox").map(\.sessionID) == [OpenCodeDeletionFixture.retainedSessionID])

        try FileManager.default.removeItem(at: fixture.hostDatabase.file)
        #expect(try fixture.discovery.discover(host: "devbox").isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.mirrorDatabase.path))
    }
}
