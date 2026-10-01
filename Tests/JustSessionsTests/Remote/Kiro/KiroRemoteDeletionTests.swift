import Foundation
import Testing
@testable import JustSessions

struct KiroRemoteDeletionTests {
    @Test func runsNativeDeletionInTheSelectedProjectAndMirroredHomeThenDropsBothCachedFiles() throws {
        let fixture = try RemoteKiroFixture()
        defer { fixture.remove() }
        let retainedSessionID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: fixture.sessionsDirectory).writeSession(
            id: retainedSessionID,
            projectPath: fixture.projectDirectory.path,
            messageLines: KiroTranscriptSamples.lines
        )
        let reportFile = fixture.root.appendingPathComponent("report.txt")
        let runner = try fixture.runner(running: KiroHomeFixture.successfulDeletionScript + "\n"
            + "printf '%s\\n' \"$@\" \"$KIRO_HOME\" \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n")

        try RemoteConversationDeletion(runner: runner).delete(fixture.conversation)

        let report = try String(contentsOf: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(Array(report.prefix(4)) == ["chat", "--delete-session", fixture.conversation.sessionID, fixture.remoteHome.appendingPathComponent(".kiro").path])
        let reportedProjectPath = URL(fileURLWithPath: try #require(report.last)).resolvingSymlinksInPath().path
        #expect(reportedProjectPath == fixture.projectDirectory.resolvingSymlinksInPath().path, "CLI report: \(report)")
        for fileExtension in ["json", "jsonl"] {
            #expect(!FileManager.default.fileExists(atPath: fixture.sessionsDirectory.appendingPathComponent("\(fixture.conversation.sessionID).\(fileExtension)").path))
            #expect(!FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.deletingPathExtension().appendingPathExtension(fileExtension).path))
            #expect(FileManager.default.fileExists(atPath: fixture.sessionsDirectory.appendingPathComponent("\(retainedSessionID).\(fileExtension)").path))
        }
    }

    @Test(arguments: ["echo 'Session is active in another process' >&2\nexit 1", "exit 0"])
    func failedOrIncompleteNativeDeletionKeepsTheLocalMirror(_ scriptBody: String) throws {
        let fixture = try RemoteKiroFixture()
        defer { fixture.remove() }
        let deletion = RemoteConversationDeletion(runner: try fixture.runner(running: "#!/bin/sh\n\(scriptBody)\n"))

        #expect(throws: RemoteConversationDeletionError.self) { try deletion.delete(fixture.conversation) }

        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.deletingPathExtension().appendingPathExtension("json").path))
    }

    @Test func missingHistoryOnTheHostIsReportedWithoutDroppingTheMirror() throws {
        let fixture = try RemoteKiroFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.sessionsDirectory.appendingPathComponent("\(fixture.conversation.sessionID).jsonl"))

        #expect(throws: RemoteConversationDeletionError.self) {
            try RemoteConversationDeletion(runner: fixture.runner()).delete(fixture.conversation)
        }

        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test func aNativeExitCodeDoesNotMasqueradeAsMissingHistory() throws {
        let fixture = try RemoteKiroFixture()
        defer { fixture.remove() }
        let deletion = RemoteConversationDeletion(runner: try fixture.runner(running: "#!/bin/sh\nexit 3\n"))

        do {
            try deletion.delete(fixture.conversation)
            Issue.record("Kiro's failed deletion should be reported")
        } catch let error as RemoteConversationDeletionError {
            guard case let .failed(host, details) = error else {
                Issue.record("Native exit code 3 is a CLI failure, not missing remote history: \(error)")
                return
            }
            #expect(host == "devbox")
            #expect(details == "Kiro CLI exited with code 3.")
        }

        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test func metadataForAnotherSessionNeverStartsARemoteCommand() throws {
        let fixture = try RemoteKiroFixture()
        defer { fixture.remove() }
        let mirrorDirectory = fixture.conversation.sourceFile.deletingLastPathComponent()
        try KiroSessionFolderFixture(sessionsDirectory: mirrorDirectory).writeSession(
            id: fixture.conversation.sessionID,
            projectPath: "/another/project",
            messageLines: KiroTranscriptSamples.lines
        )
        let recorder = RemoteCommandRecorder()

        #expect(throws: ConversationDeletionError.invalidSource) {
            try RemoteConversationDeletion(runner: recorder.runner(answering: (0, ""))).delete(fixture.conversation)
        }

        #expect(recorder.commands.isEmpty)
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }
}
