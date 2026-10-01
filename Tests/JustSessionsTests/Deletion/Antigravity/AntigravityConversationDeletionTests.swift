import Foundation
import SQLite3
import Testing
@testable import JustSessions

struct AntigravityConversationDeletionTests {
    @Test func trashesOnlyThisSessionsFilesAndRemovesOnlyItsCLIIndexEntry() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: root)
        try fixture.writeIndex()
        let other = try AntigravitySessionFixture(configurationDirectory: root)
        try other.writeIndex()
        let brain = root.appendingPathComponent("brain/\(fixture.sessionID)")
        try FileManager.default.createDirectory(at: brain, withIntermediateDirectories: true)
        try Data("artifact".utf8).write(to: brain.appendingPathComponent("notes.md"))
        let annotations = root.appendingPathComponent("annotations/\(fixture.sessionID).pbtxt")
        try FileManager.default.createDirectory(at: annotations.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("annotation".utf8).write(to: annotations)
        try AntigravitySessionFixture.execute(["INSERT INTO conversation_summaries VALUES ('\(fixture.sessionID)', 'IDE', '', '[]', '2026-10-01', 'antigravity')"], at: root.appendingPathComponent("conversation_summaries.db"))
        let trash = root.appendingPathComponent("trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let deletion = AntigravityConversationDeletion(configurationDirectory: root, moveToTrash: { file in
            let destination = trash.appendingPathComponent(file.lastPathComponent)
            try FileManager.default.moveItem(at: file, to: destination)
            return destination
        }, isInUse: { _ in false })

        try deletion.delete(fixture.conversation)

        #expect(!FileManager.default.fileExists(atPath: fixture.databaseFile.path))
        #expect(FileManager.default.fileExists(atPath: trash.appendingPathComponent(fixture.databaseFile.lastPathComponent).path))
        #expect(FileManager.default.fileExists(atPath: trash.appendingPathComponent(fixture.sessionID + "/notes.md").path))
        #expect(FileManager.default.fileExists(atPath: trash.appendingPathComponent(annotations.lastPathComponent).path))
        #expect(FileManager.default.fileExists(atPath: other.databaseFile.path))
        #expect(AntigravitySQLiteReader.summaries(at: root.appendingPathComponent("conversation_summaries.db")).keys.sorted() == [other.sessionID])
        #expect(try rowCount(in: root.appendingPathComponent("conversation_summaries.db")) == 2)
    }

    @Test func trashFailureRestoresMovedFilesAndRollsBackTheIndex() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: root)
        try fixture.writeIndex()
        let brain = root.appendingPathComponent("brain/\(fixture.sessionID)")
        try FileManager.default.createDirectory(at: brain, withIntermediateDirectories: true)
        let staged = root.appendingPathComponent("trashed.db")
        let deletion = AntigravityConversationDeletion(configurationDirectory: root, moveToTrash: { file in
            guard file.pathExtension == "db" else { throw AntigravityDatabaseError.unreadable }
            try FileManager.default.moveItem(at: file, to: staged)
            return staged
        }, isInUse: { _ in false })

        #expect(throws: AntigravityDatabaseError.self) { try deletion.delete(fixture.conversation) }
        #expect(FileManager.default.fileExists(atPath: fixture.databaseFile.path))
        #expect(try rowCount(in: root.appendingPathComponent("conversation_summaries.db")) == 1)
        #expect(try AntigravityAdapter(configurationDirectory: root).discover().count == 1)
    }

    @Test func refusesAChangedProjectSymlinkAndRemoteConversation() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: root)
        let deletion = AntigravityConversationDeletion(configurationDirectory: root, isInUse: { _ in false })
        let wrongProject = Conversation.fixture(provider: .antigravity, sessionID: fixture.sessionID, projectPath: "/another/project", sourceFile: fixture.databaseFile)
        #expect(throws: ConversationDeletionError.invalidSource) { try deletion.delete(wrongProject) }
        #expect(throws: ConversationDeletionError.invalidSource) { try deletion.delete(fixture.conversation.onHost(.ssh("devbox"))) }
        let brain = root.appendingPathComponent("brain")
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: brain, withDestinationURL: outside)
        #expect(throws: ConversationDeletionError.invalidSource) { try deletion.delete(fixture.conversation) }
        #expect(FileManager.default.fileExists(atPath: fixture.databaseFile.path))
    }

    @Test func realProcessCheckProtectsAnOpenDatabase() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: root)
        let handle = try FileHandle(forReadingFrom: fixture.databaseFile)
        defer { try? handle.close() }
        #expect(throws: AntigravityConversationDeletionError.sessionInUse) {
            try AntigravityConversationDeletion(configurationDirectory: root).delete(fixture.conversation)
        }
        #expect(FileManager.default.fileExists(atPath: fixture.databaseFile.path))
    }

    private func rowCount(in file: URL) throws -> Int32 {
        let database = try AntigravityDatabase.open(file)
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        sqlite3_prepare_v2(database, "SELECT count(*) FROM conversation_summaries", -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        sqlite3_step(statement)
        return sqlite3_column_int(statement, 0)
    }
}
