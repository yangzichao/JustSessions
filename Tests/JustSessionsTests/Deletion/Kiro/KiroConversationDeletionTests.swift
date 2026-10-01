import Foundation
import Testing
@testable import JustSessions

struct KiroConversationDeletionTests {
    @Test func deletesOnlyTheSelectedSessionUsingItsCLIHomeAndProject() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let retainedSessionID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: fixture.sessionsDirectory).writeSession(
            id: retainedSessionID,
            projectPath: fixture.projectDirectory.path,
            messageLines: [KiroSessionFolderFixture.prompt("Keep me")]
        )
        let reportFile = fixture.root.appendingPathComponent("report.txt")
        let executable = try fixture.executable(running: KiroHomeFixture.successfulDeletionScript + "\n"
            + "printf '%s\\n' \"$@\" \"$KIRO_HOME\" \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n")
        let adapter = KiroAdapter(sessionsDirectory: fixture.sessionsDirectory, deletionExecutableURL: executable)
        let selected = try #require(adapter.discover().first { $0.sessionID == fixture.conversation.sessionID })

        try adapter.delete(selected)

        let report = try String(contentsOf: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(Array(report.prefix(4)) == ["chat", "--delete-session", selected.sessionID, fixture.kiroDirectory.path])
        let workingDirectory = try #require(report.last)
        #expect(URL(fileURLWithPath: workingDirectory).resolvingSymlinksInPath().path == fixture.projectDirectory.resolvingSymlinksInPath().path)
        #expect(!FileManager.default.fileExists(atPath: selected.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.metadataFile.path))
        #expect(try adapter.discover().map(\.sessionID) == [retainedSessionID])
    }

    @Test func canDeleteHistoryAfterItsProjectDirectoryWasRemoved() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.projectDirectory)
        let reportFile = fixture.root.appendingPathComponent("working-directory.txt")

        try fixture.delete(runningScript: KiroHomeFixture.successfulDeletionScript + "\n"
            + "printf '%s\\n' \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n")

        let workingDirectory = try String(contentsOf: reportFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(URL(fileURLWithPath: workingDirectory).resolvingSymlinksInPath().path == fixture.kiroDirectory.resolvingSymlinksInPath().path)
        #expect(try KiroAdapter(sessionsDirectory: fixture.sessionsDirectory).discover().isEmpty)
    }

    @Test func aHangingCLIIsStoppedAndBothSessionFilesRemain() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let clock = ContinuousClock()
        let startedAt = clock.now

        #expect(throws: KiroConversationDeletionError.didNotFinish) {
            try fixture.delete(runningScript: "#!/bin/sh\nexec /bin/sleep 30\n", timeout: 0.5)
        }

        #expect(clock.now - startedAt < .seconds(10))
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.metadataFile.path))
    }

    @Test(arguments: [
        ("echo 'Session is active in another process' >&2\nexit 1", KiroConversationDeletionError.failed("Session is active in another process")),
        ("exit 7", .failed("Exit code 7")),
        ("printf '%0600d' 0 >&2\nexit 1", .failed(String(repeating: "0", count: 500))),
        ("exit 0", .sourceStillPresent),
    ])
    func reportsCLIFailuresWithoutRemovingHistory(scriptBody: String, expectedError: KiroConversationDeletionError) throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }

        #expect(throws: expectedError) {
            try fixture.delete(runningScript: "#!/bin/sh\n\(scriptBody)\n")
        }

        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.metadataFile.path))
    }

    @Test(arguments: ["json", "jsonl"])
    func successRequiresBothSessionFilesToBeGone(_ retainedExtension: String) throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let removedExtension = retainedExtension == "json" ? "jsonl" : "json"

        #expect(throws: KiroConversationDeletionError.sourceStillPresent) {
            try fixture.delete(runningScript: """
                #!/bin/sh
                /bin/rm -f "$KIRO_HOME/sessions/cli/$3.\(removedExtension)"
                """)
        }

        #expect(FileManager.default.fileExists(atPath: fixture.sessionsDirectory
            .appendingPathComponent("\(fixture.conversation.sessionID).\(retainedExtension)").path))
    }
}
