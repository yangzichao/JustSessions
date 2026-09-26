import Foundation
import Testing
@testable import JustSessions

struct CodexConversationDeletionTests {
    @Test func runsCodexDeleteWithTheExactSessionIDInCodexsOwnHome() throws {
        let fixture = try CodexHomeFixture()
        defer { fixture.remove() }
        let reportFile = fixture.root.appendingPathComponent("report.txt")

        try fixture.delete(runningScript: """
            #!/bin/sh
            printf '%s\\n' "$@" "CODEX_HOME=$CODEX_HOME" "$(pwd -P)" > '\(reportFile.path)'
            /bin/rm -f '\(fixture.conversation.sourceFile.path)'
            """)

        let reportLines = try String(contentsOf: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(reportLines.prefix(4) == ["delete", "--force", fixture.conversation.sessionID, "CODEX_HOME=\(fixture.codexDirectory.path)"])
        let workingDirectory = try #require(reportLines.last)
        #expect(URL(fileURLWithPath: workingDirectory).resolvingSymlinksInPath() == fixture.codexDirectory.resolvingSymlinksInPath())
        #expect(!fixture.sessionFileExists)
    }

    @Test func aCodexThatHangsIsStoppedAndTheSessionKept() throws {
        let fixture = try CodexHomeFixture()
        defer { fixture.remove() }
        let clock = ContinuousClock()
        let startedAt = clock.now

        #expect(throws: ConversationDeletionError.codexDidNotFinish) {
            try fixture.delete(runningScript: "#!/bin/sh\nexec /bin/sleep 30\n", timeout: 0.5)
        }
        #expect(clock.now - startedAt < .seconds(10))
        #expect(fixture.sessionFileExists)
    }

    @Test(arguments: [
        ("echo 'Error: the session is in use' >&2\nexit 1", ConversationDeletionError.codexFailed("Error: the session is in use")),
        ("exit 7", .codexFailed("Exit code 7")),
        ("printf 'x%.0s' $(/usr/bin/seq 1 2000)\nexit 1", .codexFailed(String(repeating: "x", count: 500))),
        ("exit 0", .sourceStillPresent),
    ])
    func whatCodexReportsIsShownAndTheSessionKept(scriptBody: String, expectedError: ConversationDeletionError) throws {
        let fixture = try CodexHomeFixture()
        defer { fixture.remove() }

        #expect(throws: expectedError) {
            try fixture.delete(runningScript: "#!/bin/sh\n\(scriptBody)\n")
        }
        #expect(fixture.sessionFileExists)
    }

    @Test func aSessionFileOutsideCodexsFolderIsNeverPassedToCodex() throws {
        let fixture = try CodexHomeFixture()
        defer { fixture.remove() }
        let outsideDirectory = fixture.root.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        let outsideFile = outsideDirectory.appendingPathComponent("rollout-2026-09-23T10-00-00-\(sessionID).jsonl")
        try CodexHomeFixture.sessionMetaLine(sessionID: sessionID).write(to: outsideFile, atomically: true, encoding: .utf8)
        let linkInsideSessions = fixture.sessionsDirectory.appendingPathComponent("rollout-linked-\(sessionID).jsonl")
        try FileManager.default.createSymbolicLink(at: linkInsideSessions, withDestinationURL: outsideFile)
        let codexRanMarker = fixture.root.appendingPathComponent("codex-ran")

        for sourceFile in [outsideFile, linkInsideSessions] {
            let conversation = Conversation.fixture(provider: .codex, sessionID: sessionID, sourceFile: sourceFile)
            #expect(throws: ConversationDeletionError.invalidSource) {
                try fixture.delete(conversation, runningScript: "#!/bin/sh\n/usr/bin/touch '\(codexRanMarker.path)'\n")
            }
        }
        #expect(!FileManager.default.fileExists(atPath: codexRanMarker.path))
        #expect(FileManager.default.fileExists(atPath: outsideFile.path))
    }

    @Test func aFileThatBelongsToAnotherSessionIsRefused() throws {
        let fixture = try CodexHomeFixture()
        defer { fixture.remove() }
        let otherSessionID = UUID().uuidString.lowercased()
        let mislabeledConversation = Conversation.fixture(
            provider: .codex,
            sessionID: otherSessionID,
            sourceFile: fixture.conversation.sourceFile
        )

        #expect(throws: ConversationDeletionError.invalidSource) {
            try fixture.delete(mislabeledConversation, runningScript: "#!/bin/sh\n/bin/rm -f '\(fixture.conversation.sourceFile.path)'\n")
        }
        #expect(fixture.sessionFileExists)
    }
}
