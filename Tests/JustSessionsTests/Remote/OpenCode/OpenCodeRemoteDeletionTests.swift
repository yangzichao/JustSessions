import Foundation
import Testing
@testable import JustSessions

struct OpenCodeRemoteDeletionTests {
    @Test func deletesWithTheHostsCLIAndDropsOnlyThatSessionFromTheMirror() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        let selected = try fixture.mirroredConversation()
        let reportFile = fixture.root.appendingPathComponent("report.txt")
        let script = OpenCodeDeletionFixture.deletingScript.replacingOccurrences(
            of: "#!/bin/sh\n",
            with: "#!/bin/sh\nprintf '%s\\n' \"$@\" \"$OPENCODE_DB\" \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n"
        )

        try fixture.deletion(running: script).delete(selected)

        let report = try String(contentsOf: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(Array(report.prefix(4)) == ["session", "delete", selected.sessionID, fixture.hostDatabase.file.path])
        let workingDirectory = URL(fileURLWithPath: try #require(report.last)).resolvingSymlinksInPath().path
        #expect(workingDirectory == fixture.hostDatabase.file.deletingLastPathComponent().resolvingSymlinksInPath().path)
        #expect(try fixture.hostDatabase.count("SELECT count(*) FROM session") == 1)
        #expect(try OpenCodeAdapter(databaseFile: fixture.mirrorDatabase).discover().map(\.sessionID) == [OpenCodeDeletionFixture.retainedSessionID])
        #expect(try OpenCodeTranscriptReader().read(fixture.mirrorDatabase, sessionID: selected.sessionID).entries.isEmpty)
        #expect(try fixture.discovery.readMirror(host: "devbox").map(\.sessionID) == [OpenCodeDeletionFixture.retainedSessionID])
    }

    @Test func deletesFromTheDatabaseTheLoginShellPointsOpenCodeTo() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        let selected = try fixture.mirroredConversation()
        let customData = fixture.root.appendingPathComponent("custom data")
        try FileManager.default.createDirectory(at: customData.appendingPathComponent("opencode"), withIntermediateDirectories: true)
        let customDatabase = customData.appendingPathComponent("opencode/opencode.db")
        try FileManager.default.moveItem(at: fixture.hostDatabase.file, to: customDatabase)

        try fixture.deletion(environment: ["XDG_DATA_HOME": customData.path]).delete(selected)

        #expect(try OpenCodeDatabaseFixture(file: customDatabase, createsTables: false).count("SELECT count(*) FROM session") == 1)
    }

    @Test func aSessionOpenCodeNoLongerHasCountsAsDeleted() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        let selected = try fixture.mirroredConversation()
        try fixture.hostDatabase.execute("DELETE FROM session WHERE id = ?", [selected.sessionID])

        try fixture.deletion().delete(selected)

        #expect(try OpenCodeAdapter(databaseFile: fixture.mirrorDatabase).discover().map(\.sessionID) == [OpenCodeDeletionFixture.retainedSessionID])
    }

    @Test func aFailedDeletionKeepsTheMirrorAndReportsOpenCodesError() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        let selected = try fixture.mirroredConversation()
        let deletion = try fixture.deletion(running: #"""
            #!/bin/sh
            printf '\033[91m\033[1mError: \033[0mdatabase is locked\n' >&2
            exit 1
            """#)

        do {
            try deletion.delete(selected)
            Issue.record("A failed deletion should be reported")
        } catch let error as RemoteConversationDeletionError {
            guard case let .failed(host, details) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(host == "devbox")
            #expect(details == "Error: database is locked\nOpenCode exited with code 1.")
        }

        #expect(try OpenCodeAdapter(databaseFile: fixture.mirrorDatabase).discover().count == 2)
    }

    @Test func aSessionTheMirrorDoesNotHoldNeverStartsARemoteCommand() throws {
        let fixture = try RemoteOpenCodeFixture()
        defer { fixture.remove() }
        let selected = try fixture.mirroredConversation()
        let recorder = RemoteCommandRecorder()
        let deletion = RemoteConversationDeletion(runner: recorder.runner(answering: (0, "")), mirror: RemoteSessionMirror(cacheRoot: fixture.cacheRoot))
        func copy(sessionID: String? = nil, projectPath: String? = nil, sourceFile: URL? = nil, host: SessionHost = .ssh("devbox")) -> Conversation {
            .fixture(
                provider: .opencode,
                sessionID: sessionID ?? selected.sessionID,
                projectPath: projectPath ?? selected.projectPath,
                sourceFile: sourceFile ?? selected.sourceFile,
                host: host
            )
        }

        for conversation in [
            copy(sessionID: "ses_bad'; rm -rf ~"),
            copy(sessionID: UUID().uuidString),
            copy(sessionID: OpenCodeDeletionFixture.subagentSessionID),
            copy(sessionID: "ses_notmirrored01"),
            copy(projectPath: "/srv/elsewhere"),
            copy(sourceFile: fixture.hostDatabase.file),
            copy(host: .ssh("laptop")),
        ] {
            #expect(throws: ConversationDeletionError.self) { try deletion.delete(conversation) }
        }

        #expect(recorder.commands.isEmpty)
    }
}
