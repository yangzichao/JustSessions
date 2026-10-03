import Foundation
import Testing
@testable import JustSessions

struct OpenCodeConversationDeletionTests {
    @Test func deletesTheSessionAndItsSubagentsThroughTheCLIAndTheDatabaseItWasListedFrom() throws {
        let fixture = try OpenCodeDeletionFixture()
        defer { fixture.remove() }
        let adapter = try fixture.adapter()

        try adapter.delete(try fixture.selectedConversation())

        let report = try fixture.report()
        #expect(Array(report.prefix(4)) == ["session", "delete", OpenCodeDeletionFixture.selectedSessionID, fixture.database.file.path])
        let workingDirectory = URL(fileURLWithPath: try #require(report.last)).resolvingSymlinksInPath()
        #expect(workingDirectory.path == fixture.database.file.deletingLastPathComponent().resolvingSymlinksInPath().path)
        #expect(try adapter.discover().map(\.sessionID) == [OpenCodeDeletionFixture.retainedSessionID])
        #expect(try fixture.database.count("SELECT count(*) FROM session") == 1)
        #expect(try fixture.database.count("SELECT count(*) FROM message") == 1)
        #expect(try fixture.database.count("SELECT count(*) FROM part") == 1)
    }

    @Test(arguments: [
        (#"printf '\033[91m\033[1mError: \033[0mdatabase is locked\n' >&2"# + "\nexit 1", OpenCodeConversationDeletionError.failed("Error: database is locked")),
        ("exit 7", .failed("Exit code 7")),
        ("printf '%0600d' 0 >&2\nexit 1", .failed(String(repeating: "0", count: 500))),
        ("exit 0", .sessionStillPresent),
    ])
    func reportsCLIFailuresAndKeepsTheSession(scriptBody: String, expectedError: OpenCodeConversationDeletionError) throws {
        let fixture = try OpenCodeDeletionFixture()
        defer { fixture.remove() }
        let adapter = try fixture.adapter(running: "#!/bin/sh\n\(scriptBody)\n")

        #expect(throws: expectedError) { try adapter.delete(try fixture.selectedConversation()) }

        #expect(try adapter.discover().count == 2)
    }

    @Test func aHangingCLIIsStoppedAndTheSessionRemains() throws {
        let fixture = try OpenCodeDeletionFixture()
        defer { fixture.remove() }
        let deletion = OpenCodeConversationDeletion(
            databaseFile: fixture.database.file,
            executableURL: try fixture.executable(running: "#!/bin/sh\nexec /bin/sleep 30\n"),
            timeout: 0.5
        )
        let clock = ContinuousClock()
        let startedAt = clock.now

        #expect(throws: OpenCodeConversationDeletionError.didNotFinish) { try deletion.delete(try fixture.selectedConversation()) }

        #expect(clock.now - startedAt < .seconds(10))
        #expect(try fixture.database.count("SELECT count(*) FROM session") == 3)
    }

    @Test func refusesSessionsThatDoNotMatchTheDatabaseWithoutRunningTheCLI() throws {
        let fixture = try OpenCodeDeletionFixture()
        defer { fixture.remove() }
        let adapter = try fixture.adapter()
        let selected = try fixture.selectedConversation()
        let otherDatabase = fixture.root.appendingPathComponent("other.db")
        func copy(sessionID: String? = nil, projectPath: String? = nil, sourceFile: URL? = nil, host: SessionHost = .thisMac) -> Conversation {
            .fixture(
                provider: .opencode,
                sessionID: sessionID ?? selected.sessionID,
                projectPath: projectPath ?? selected.projectPath,
                sourceFile: sourceFile ?? selected.sourceFile,
                host: host
            )
        }

        #expect(throws: ConversationDeletionError.invalidSource) { try adapter.delete(copy(sourceFile: otherDatabase)) }
        #expect(throws: ConversationDeletionError.invalidSource) { try adapter.delete(copy(sessionID: "ses_bad; rm -rf ~")) }
        #expect(throws: ConversationDeletionError.invalidSource) { try adapter.delete(copy(host: .ssh("devbox"))) }
        #expect(throws: ConversationDeletionError.missingSource) { try adapter.delete(copy(sessionID: "ses_alreadygone01")) }
        #expect(throws: ConversationDeletionError.sourceMismatch) { try adapter.delete(copy(projectPath: "/Users/me/elsewhere")) }
        // Subagent sessions are never listed; deleting their parent deletes them.
        #expect(throws: ConversationDeletionError.sourceMismatch) {
            try adapter.delete(copy(sessionID: OpenCodeDeletionFixture.subagentSessionID))
        }

        #expect(!FileManager.default.fileExists(atPath: fixture.reportFile.path))
        #expect(try fixture.database.count("SELECT count(*) FROM session") == 3)
    }

    @Test func escapeSequencesAreRemovedFromCLIOutput() {
        #expect(TerminalEscapeSequences.removed(from: "\u{1B}[91m\u{1B}[1mError: \u{1B}[0mSession not found") == "Error: Session not found")
        #expect(TerminalEscapeSequences.removed(from: "a\u{1B}[38;5;208mb\u{1B}cc") == "abc")
        #expect(TerminalEscapeSequences.removed(from: "plain 文本") == "plain 文本")
    }
}
