import Foundation
import Testing
@testable import JustSessions

struct PiAdapterTests {
    @Test func listsSessionsInProjectFoldersAndTheSessionsFolderItself() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = PiSessionFolderFixture(sessionsDirectory: root)
        let namedID = UUID().uuidString.lowercased()
        let promptedID = UUID().uuidString.lowercased()
        let emptyID = UUID().uuidString.lowercased()
        try fixture.writeSession(id: namedID, projectPath: "/Users/me/app", lines: [
            PiSessionFolderFixture.userMessage("Fix the login bug"),
            PiSessionFolderFixture.sessionName("Old name"),
            PiSessionFolderFixture.sessionName("Login fix"),
        ])
        try fixture.writeSession(id: promptedID, projectPath: "/Users/me/api", lines: [
            PiSessionFolderFixture.userMessage("Add a health check\\nwith a test"),
        ], inProjectFolder: false)
        try fixture.writeSession(id: emptyID, projectPath: "/Users/me/api")

        let found = try PiAdapter(sessionsDirectory: root).discover()

        #expect(found.count == 3)
        #expect(found.allSatisfy { $0.provider == .pi })
        let named = try #require(found.first { $0.sessionID == namedID })
        #expect(named.projectPath == "/Users/me/app")
        #expect(named.suggestedTitle == "Login fix")
        #expect(found.first { $0.sessionID == promptedID }?.suggestedTitle == "Add a health check")
        #expect(found.first { $0.sessionID == emptyID }?.suggestedTitle == ConversationMetadata.untitledConversationTitle)
    }

    /// Subagent runs and forks sit in the folder named after the session file that started them, at any depth.
    @Test func listsEachSubagentsSessionUnderTheSessionThatStartedIt() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = PiSessionFolderFixture(sessionsDirectory: root)
        let parentID = UUID().uuidString.lowercased()
        let runID = UUID().uuidString.lowercased()
        let nestedID = UUID().uuidString.lowercased()
        let forkID = UUID().uuidString.lowercased()
        let parentFile = try fixture.writeSession(id: parentID, projectPath: "/Users/me/app", lines: [
            PiSessionFolderFixture.userMessage("Plan the release"),
        ])
        let runFile = try fixture.writeSubagentSession(id: runID, at: "run-a/run-0/session.jsonl", inFolderOf: parentFile, lines: [
            PiSessionFolderFixture.userMessage("Task: Review the diff"),
            PiSessionFolderFixture.sessionName("subagent-reviewer-run-a-1"),
        ])
        try fixture.writeSubagentSession(
            id: nestedID,
            at: "run-a/run-0/session/run-b/run-0/session.jsonl",
            inFolderOf: parentFile,
            projectPath: "/Users/me/other",
            lines: [PiSessionFolderFixture.userMessage("Task: Check the tests")]
        )
        try fixture.writeSubagentSession(
            id: forkID,
            at: "forks/2026-09-30T10-05-00-000Z_\(forkID).jsonl",
            inFolderOf: parentFile,
            forkedFrom: parentFile,
            lines: [PiSessionFolderFixture.userMessage("Plan the release"), PiSessionFolderFixture.userMessage("Task: Write the notes")]
        )
        // An extension's own record of a run is no Pi session.
        let artifacts = parentFile.deletingPathExtension().appendingPathComponent("run-a/run-0/subagent-artifacts")
        try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)
        try #"{"recordType":"message","runId":"run-a"}"#.appending("\n")
            .write(to: artifacts.appendingPathComponent("run-a_worker_transcript.jsonl"), atomically: true, encoding: .utf8)

        let found = Dictionary(uniqueKeysWithValues: try PiAdapter(sessionsDirectory: root).discover().map { ($0.sessionID, $0) })

        #expect(Set(found.keys) == [parentID, runID, nestedID, forkID])
        #expect(found[parentID]?.parentSessionID == nil)
        let run = try #require(found[runID])
        #expect(run.parentSessionID == parentID)
        #expect(run.suggestedTitle == "Task: Review the diff")
        #expect(run.sourceFile.resolvingSymlinksInPath() == runFile.resolvingSymlinksInPath())
        #expect(run.projectPath == "/Users/me/app")
        #expect(found[nestedID]?.parentSessionID == runID)
        #expect(found[nestedID]?.projectPath == "/Users/me/other")
        // A fork opens with its parent's history, so its own task is its latest prompt.
        #expect(found[forkID]?.parentSessionID == parentID)
        #expect(found[forkID]?.suggestedTitle == "Task: Write the notes")
    }

    @Test func skipsFilesThatAreNotPiSessions() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = PiSessionFolderFixture(sessionsDirectory: root)
        try fixture.writeSession(id: UUID().uuidString, projectPath: "/Users/me/app", fileSessionID: UUID().uuidString)
        try fixture.writeSession(id: "not-a-uuid", projectPath: "/Users/me/app")
        try fixture.writeSession(id: UUID().uuidString, projectPath: "relative/path")
        let notesFile = root.appendingPathComponent("notes.jsonl")
        try #"{"type":"note","id":"x"}"#.appending("\n").write(to: notesFile, atomically: true, encoding: .utf8)

        #expect(try PiAdapter(sessionsDirectory: root).discover().isEmpty)
        #expect(try PiAdapter(sessionsDirectory: root.appendingPathComponent("missing")).discover().isEmpty)
    }

    /// The adapter deletes only from its own sessions folder; moving to the Trash is covered by
    /// `PiConversationDeletionTests`. Any move here fails the test rather than reaching the real Trash.
    @Test func deletionRefusesASessionOutsideTheAdaptersSessionsFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try PiSessionFolderFixture(sessionsDirectory: root.appendingPathComponent("elsewhere"))
            .writeSession(id: sessionID, projectPath: "/Users/me/app")
        let conversation = Conversation.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile)

        let adapter = PiAdapter(sessionsDirectory: root.appendingPathComponent("sessions")) { url in
            Issue.record("Nothing should move to the Trash: \(url.lastPathComponent)")
        }

        #expect(throws: ConversationDeletionError.invalidSource) {
            try adapter.delete(conversation)
        }
        #expect(FileManager.default.fileExists(atPath: sessionFile.path))
    }
}
