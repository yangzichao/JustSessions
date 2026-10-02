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

    @Test func sessionsAreDeletableOnThisMacAndOnSSHHosts() {
        #expect(ConversationProvider.pi.supportsDeletionFromLauncher)
        #expect(ConversationProvider.pi.supportsRemoteHosts)
        #expect(ConversationProvider.pi.runs(on: .ssh("devbox")))
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
