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
        let executable = try fixture.executable(
            running: KiroHomeFixture.successfulDeletionScript + "\n"
                + "printf '%s\\n' \"$@\" \"$KIRO_HOME\" \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n")
        let adapter = KiroAdapter(sessionsDirectory: fixture.sessionsDirectory, deletionExecutableURL: executable)
        let selected = try #require(adapter.discover().first { $0.sessionID == fixture.conversation.sessionID })

        try adapter.delete(selected)

        let report = try String(contentsOf: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(Array(report.prefix(4)) == ["chat", "--delete-session", selected.sessionID, fixture.kiroDirectory.path])
        let workingDirectory = try #require(report.last)
        #expect(
            URL(fileURLWithPath: workingDirectory).resolvingSymlinksInPath().path == fixture.projectDirectory.resolvingSymlinksInPath().path
        )
        #expect(!FileManager.default.fileExists(atPath: selected.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.metadataFile.path))
        #expect(try adapter.discover().map(\.sessionID) == [retainedSessionID])
    }

    @Test func canDeleteHistoryAfterItsProjectDirectoryWasRemoved() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.projectDirectory)
        let reportFile = fixture.root.appendingPathComponent("working-directory.txt")

        try fixture.delete(
            runningScript: KiroHomeFixture.successfulDeletionScript + "\n"
                + "printf '%s\\n' \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n")

        let workingDirectory = try String(contentsOf: reportFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(
            URL(fileURLWithPath: workingDirectory).resolvingSymlinksInPath().path == fixture.kiroDirectory.resolvingSymlinksInPath().path)
        #expect(try KiroAdapter(sessionsDirectory: fixture.sessionsDirectory).discover().isEmpty)
    }

    @Test func aHangingCLIIsStoppedAndBothSessionFilesRemain() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let clock = ContinuousClock()
        let startedAt = clock.now

        #expect(throws: KiroConversationDeletionError.didNotFinish) {
            try fixture.delete(runningScript: "#!/bin/sh\nexec /bin/sleep 600\n", timeout: 0.5)
        }

        // Well short of the stand-in's 600 seconds, so the time limit, not the CLI ending, stopped the wait.
        #expect(clock.now - startedAt < .seconds(120))
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.metadataFile.path))
    }

    @Test(arguments: [
        (
            "echo 'Session is active in another process' >&2\nexit 1",
            KiroConversationDeletionError.failed("Session is active in another process")
        ),
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
            try fixture.delete(
                runningScript: """
                    #!/bin/sh
                    /bin/rm -f "$KIRO_HOME/sessions/cli/$3.\(removedExtension)"
                    """)
        }

        #expect(
            FileManager.default.fileExists(
                atPath: fixture.sessionsDirectory
                    .appendingPathComponent("\(fixture.conversation.sessionID).\(retainedExtension)").path))
    }

    /// Kiro CLI 2.34.0 keeps a session a running CLI holds and says it deleted it, so the app doesn't ask it.
    @Test func aSessionARunningCLIHoldsIsNotHandedToKiro() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let lockFile = KiroSessionLock.file(forSessionFile: fixture.conversation.sourceFile)
        try KiroSessionLockTests.writeLock(processID: getpid(), startedAt: .now, to: lockFile)
        let ranFile = fixture.root.appendingPathComponent("ran")

        #expect(throws: KiroConversationDeletionError.stillRunning) {
            try fixture.delete(runningScript: "#!/bin/sh\ntouch \(ShellQuoting.quoted(ranFile.path))\n")
        }

        #expect(!FileManager.default.fileExists(atPath: ranFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.metadataFile.path))
    }

    /// A CLI that ended without removing its lock, as after a crash, doesn't stop the deletion, and its lock goes too.
    @Test func theLockOfACLIThatEndedDoesNotStopTheDeletionAndGoesWithIt() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let lockFile = KiroSessionLock.file(forSessionFile: fixture.conversation.sourceFile)
        try KiroSessionLockTests.writeLock(processID: try KiroSessionLockTests.endedProcessID(), startedAt: .now, to: lockFile)

        try fixture.delete(runningScript: KiroHomeFixture.successfulDeletionScript)

        #expect(!FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: lockFile.path))
    }

    /// Kiro leaves `<id>.history`, the prompts typed in the session; it goes with the session, and another's stays.
    @Test func thePromptsKiroLeavesGoWithTheSession() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let history = fixture.sessionsDirectory.appendingPathComponent("\(fixture.conversation.sessionID).history")
        let otherHistory = fixture.sessionsDirectory.appendingPathComponent("\(UUID().uuidString.lowercased()).history")
        try "Fix the login bug\n".write(to: history, atomically: true, encoding: .utf8)
        try "Keep me\n".write(to: otherHistory, atomically: true, encoding: .utf8)

        try fixture.delete(runningScript: KiroHomeFixture.successfulDeletionScript)

        #expect(!FileManager.default.fileExists(atPath: history.path))
        #expect(FileManager.default.fileExists(atPath: otherHistory.path))
    }

    @Test func aHistoryThatIsASymbolicLinkIsLeftWithWhatItPointsTo() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let target = fixture.root.appendingPathComponent("elsewhere.txt")
        try "not Kiro's\n".write(to: target, atomically: true, encoding: .utf8)
        let history = fixture.sessionsDirectory.appendingPathComponent("\(fixture.conversation.sessionID).history")
        try FileManager.default.createSymbolicLink(at: history, withDestinationURL: target)

        try fixture.delete(runningScript: KiroHomeFixture.successfulDeletionScript)

        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: history.path)) == target.path)
    }
}
