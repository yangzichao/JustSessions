import Foundation
import Testing
@testable import JustSessions

struct AntigravityRemoteDeletionTests {
    @Test func deletesTheValidatedSessionAndItsCacheWhilePreservingOtherSessions() throws {
        let fixture = try RemoteAntigravityFixture()
        defer { fixture.remove() }
        let other = try AntigravitySessionFixture(configurationDirectory: fixture.session.configurationDirectory)
        try other.writeIndex()
        let brain = fixture.session.configurationDirectory.appendingPathComponent("brain/\(fixture.session.sessionID)")
        try FileManager.default.createDirectory(at: brain, withIntermediateDirectories: true)
        try Data("notes".utf8).write(to: brain.appendingPathComponent("notes.md"))

        try RemoteConversationDeletion(runner: fixture.runner()).delete(fixture.conversation)

        #expect(!FileManager.default.fileExists(atPath: fixture.session.databaseFile.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: brain.path))
        #expect(FileManager.default.fileExists(atPath: other.databaseFile.path))
        #expect(try AntigravityAdapter(configurationDirectory: fixture.session.configurationDirectory).discover().map(\.sessionID) == [other.sessionID])
    }

    @Test func activeSessionAndChangedRemoteMetadataPreserveBothHostAndCache() throws {
        let fixture = try RemoteAntigravityFixture()
        defer { fixture.remove() }
        #expect(throws: RemoteConversationDeletionError.self) {
            try RemoteConversationDeletion(runner: fixture.runner(lsofExitStatus: 0)).delete(fixture.conversation)
        }
        try AntigravitySessionFixture.execute(["UPDATE trajectory_meta SET cascade_id = '\(UUID().uuidString)'"], at: fixture.session.databaseFile)
        #expect(throws: RemoteConversationDeletionError.self) {
            try RemoteConversationDeletion(runner: fixture.runner()).delete(fixture.conversation)
        }
        #expect(FileManager.default.fileExists(atPath: fixture.session.databaseFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test func missingRemoteDatabaseReportsMissingWithoutRemovingTheCache() throws {
        let fixture = try RemoteAntigravityFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.session.databaseFile)
        do {
            try RemoteConversationDeletion(runner: fixture.runner()).delete(fixture.conversation)
            Issue.record("Expected the missing-session error")
        } catch RemoteConversationDeletionError.missingOnHost(let host) {
            #expect(host == "devbox")
        }
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test func aFailureAfterStagingTheDatabaseRestoresFilesAndTheIndex() throws {
        let fixture = try RemoteAntigravityFixture()
        defer { fixture.remove() }
        let brain = fixture.session.configurationDirectory.appendingPathComponent("brain")
        try FileManager.default.createDirectory(at: brain.appendingPathComponent(fixture.session.sessionID), withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: brain.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: brain.path) }

        #expect(throws: RemoteConversationDeletionError.self) {
            try RemoteConversationDeletion(runner: fixture.runner()).delete(fixture.conversation)
        }

        #expect(FileManager.default.fileExists(atPath: fixture.session.databaseFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
        #expect(AntigravitySQLiteReader.summaries(at: fixture.session.configurationDirectory.appendingPathComponent("conversation_summaries.db"))[fixture.session.sessionID] != nil)
        #expect(try AntigravityAdapter(configurationDirectory: fixture.session.configurationDirectory).discover().count == 1)
    }
}
