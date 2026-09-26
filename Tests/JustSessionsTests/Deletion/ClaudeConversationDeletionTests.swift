import Foundation
import Testing
@testable import JustSessions

struct ClaudeConversationDeletionTests {
    @Test func movesOnlyTheSelectedSessionAndItsFolderToTheTrash() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let configurationDirectory = root.appendingPathComponent(".claude")
        let projectDirectory = configurationDirectory.appendingPathComponent("projects/project")
        let trashDirectory = root.appendingPathComponent("test-trash")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        let deletedID = UUID().uuidString
        let retainedID = UUID().uuidString
        let deletedFile = projectDirectory.appendingPathComponent("\(deletedID).jsonl")
        let retainedFile = projectDirectory.appendingPathComponent("\(retainedID).jsonl")
        let companionDirectory = projectDirectory.appendingPathComponent(deletedID)
        try "conversation".write(to: deletedFile, atomically: true, encoding: .utf8)
        try "other conversation".write(to: retainedFile, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: companionDirectory, withIntermediateDirectories: true)
        try "artifact".write(to: companionDirectory.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        let index: [String: Any] = [
            "originalPath": "/example",
            "entries": [["sessionId": deletedID], ["sessionId": retainedID]],
        ]
        let indexFile = projectDirectory.appendingPathComponent("sessions-index.json")
        try JSONSerialization.data(withJSONObject: index).write(to: indexFile)
        let conversation = Conversation.fixture(sessionID: deletedID, projectPath: "/example", sourceFile: deletedFile)
        let deletion = ClaudeConversationDeletion(configurationDirectory: configurationDirectory) { source in
            try FileManager.default.moveItem(at: source, to: trashDirectory.appendingPathComponent(source.lastPathComponent))
        }

        try deletion.delete(conversation)

        #expect(!FileManager.default.fileExists(atPath: deletedFile.path))
        #expect(FileManager.default.fileExists(atPath: retainedFile.path))
        #expect(FileManager.default.fileExists(atPath: trashDirectory.appendingPathComponent("\(deletedID).jsonl").path))
        #expect(FileManager.default.fileExists(atPath: trashDirectory.appendingPathComponent("\(deletedID)/notes.txt").path))
        let updatedIndex = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: indexFile)) as? [String: Any])
        let entries = try #require(updatedIndex["entries"] as? [[String: Any]])
        #expect(entries.map { $0["sessionId"] as? String } == [retainedID])
    }

    @Test func refusesASessionOutsideTheHistoryFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID().uuidString
        let unrelatedFile = root.appendingPathComponent("\(sessionID).jsonl")
        try "keep this".write(to: unrelatedFile, atomically: true, encoding: .utf8)
        let conversation = Conversation.fixture(sessionID: sessionID, projectPath: root.path, sourceFile: unrelatedFile)

        #expect(throws: ConversationDeletionError.invalidSource) {
            try ClaudeConversationDeletion(configurationDirectory: root.appendingPathComponent(".claude")).delete(conversation)
        }
        #expect(FileManager.default.fileExists(atPath: unrelatedFile.path))
    }

    @Test func refusesAFileNamedForAnotherSession() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectDirectory = root.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let otherSessionFile = projectDirectory.appendingPathComponent("\(UUID().uuidString).jsonl")
        try "another session".write(to: otherSessionFile, atomically: true, encoding: .utf8)
        let conversation = Conversation.fixture(sessionID: UUID().uuidString, sourceFile: otherSessionFile)

        #expect(throws: ConversationDeletionError.invalidSource) {
            try ClaudeConversationDeletion(configurationDirectory: root.appendingPathComponent(".claude")) { _ in
                Issue.record("Nothing should move to the Trash")
            }.delete(conversation)
        }
        #expect(FileManager.default.fileExists(atPath: otherSessionFile.path))
    }
}
