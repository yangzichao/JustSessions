import Foundation
import Testing
@testable import JustSessions

struct ClaudeDeletionIndexBatchTests {
    @Test func stoppingBetweenFilesFlushesOnlySuccessfullyTrashedSessions() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let project = directory.appendingPathComponent("projects/example")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let sessions = try (0..<3).map { _ -> Conversation in
            let id = UUID().uuidString
            let file = project.appendingPathComponent(id + ".jsonl")
            try Data("session".utf8).write(to: file)
            return .fixture(sessionID: id, sourceFile: file)
        }
        let index = project.appendingPathComponent("sessions-index.json")
        try JSONSerialization.data(withJSONObject: ["entries": sessions.map { ["sessionId": $0.sessionID] }]).write(to: index)
        let batch = ClaudeDeletionIndexBatch()
        let deletion = ClaudeConversationDeletion(configurationDirectory: directory,
                                                  moveToTrash: { try FileManager.default.removeItem(at: $0) }, indexBatch: batch)
        for session in sessions.prefix(2) { try deletion.delete(session) }
        #expect(batch.pendingCount == 2)
        // The deletion worker performs this flush when Cancel stops it between sessions.
        #expect(batch.flush().isEmpty)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: index)) as? [String: Any])
        #expect((object["entries"] as? [[String: String]]) == [["sessionId": sessions[2].sessionID]])
        #expect(FileManager.default.fileExists(atPath: sessions[2].sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: sessions[0].sourceFile.path))
    }

    @Test func oneWritePerProjectRetainsSessionsAddedBeforeFlush() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let index = directory.appendingPathComponent("sessions-index.json")
        let deleted = (0..<12).map { _ in Conversation.fixture() }
        let retainedID = UUID().uuidString
        var writes = 0
        let batch = ClaudeDeletionIndexBatch { ids, project in
            writes += 1
            try ClaudeConversationIndex.remove(sessionIDs: ids, in: project)
        }
        for conversation in deleted { batch.record(conversation, in: directory) }
        let entries = (deleted.map(\.sessionID) + [retainedID]).map { ["sessionId": $0] }
        try JSONSerialization.data(withJSONObject: ["entries": entries, "originalPath": "/project"]).write(to: index)
        #expect(batch.flush().isEmpty)
        #expect(batch.flush().isEmpty)
        #expect(writes == 1)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: index)) as? [String: Any])
        #expect((object["entries"] as? [[String: String]]) == [["sessionId": retainedID]])
        #expect(object["originalPath"] as? String == "/project")
    }

    @Test func indexFailureReportsEveryAlreadyRemovedSession() {
        let batch = ClaudeDeletionIndexBatch { _, _ in throw CocoaError(.fileWriteNoPermission) }
        let sessions = [Conversation.fixture(), Conversation.fixture()]
        for session in sessions { batch.record(session, in: URL(fileURLWithPath: "/test-project")) }
        let failures = batch.flush()
        #expect(Set(failures.map { $0.conversation.id }) == Set(sessions.map(\.id)))
        #expect(failures.allSatisfy { !$0.isStillListed })
        #expect(batch.pendingCount == 0)
    }
}
