import Foundation
import SQLite3
import Testing
@testable import JustSessions

struct AntigravityRemoteMirrorTests {
    @Test func snapshotsCommittedWALContentAndExcludesSettingsBrainAndAnnotations() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("remote home")
        let configuration = home.appendingPathComponent(".gemini/antigravity-cli")
        let fixture = try AntigravitySessionFixture(configurationDirectory: configuration)
        try fixture.writeIndex()
        let database = try AntigravityDatabase.open(fixture.databaseFile, writable: true)
        defer { sqlite3_close(database) }
        try AntigravityDatabase.execute("PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0", in: database)
        try fixture.appendPrompt("Committed in WAL", index: 1)
        try Data("private settings".utf8).write(to: configuration.appendingPathComponent("settings.json"))
        let brain = configuration.appendingPathComponent("brain/\(fixture.sessionID)")
        try FileManager.default.createDirectory(at: brain, withIntermediateDirectories: true)
        try Data("private artifact".utf8).write(to: brain.appendingPathComponent("artifact.md"))
        let mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: home.path)
        let discovery = RemoteSessionDiscovery(mirror: mirror)

        let conversation = try #require(discovery.discover(host: "devbox").first)
        #expect(conversation.provider == .antigravity)
        #expect(conversation.host == .ssh("devbox"))
        #expect(conversation.suggestedTitle == "Build fix")
        #expect(try AntigravityTranscriptReader().read(conversation.sourceFile).entries.last?.content == .userMessage("Committed in WAL"))
        let destination = mirror.mirrorDirectory(host: "devbox", provider: .antigravity)
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("settings.json").path))
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("brain").path))
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("annotations").path))
    }

    @Test func pythonSnapshotCommandProducesReadableDatabasesAndValidatesItsCleanupPath() throws {
        let fixture = try RemoteAntigravityFixture()
        defer { fixture.remove() }
        let result = try #require(fixture.runner().run("devbox", AntigravityRemoteSnapshotCommand.create(on: "devbox"), 30))
        #expect(result.exitStatus == 0)
        let path = try #require(AntigravityRemoteSnapshotCommand.snapshotPath(in: result.output))
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(try AntigravityAdapter(configurationDirectory: URL(fileURLWithPath: path)).discover().map(\.sessionID) == [fixture.session.sessionID])
        #expect(AntigravityRemoteSnapshotCommand.snapshotPath(in: "JUSTSESSIONS_AGY_SNAPSHOT=/tmp/justsessions-agy-../../home") == nil)
        #expect(AntigravityRemoteSnapshotCommand.snapshotPath(in: "JUSTSESSIONS_AGY_SNAPSHOT=/tmp/justsessions-agy-foo;rm -rf x") == nil)
    }

    @Test func deletedRemoteSessionsDisappearFromTheNextSnapshot() throws {
        let fixture = try RemoteAntigravityFixture()
        defer { fixture.remove() }
        let mirror = RemoteSessionMirror(cacheRoot: fixture.root.appendingPathComponent("cache"), sourceHomeOverride: fixture.home.path)
        let discovery = RemoteSessionDiscovery(mirror: mirror)
        let conversation = try #require(discovery.discover(host: "devbox").first)
        try FileManager.default.removeItem(at: fixture.session.databaseFile)
        #expect(try discovery.discover(host: "devbox").isEmpty)
        #expect(!FileManager.default.fileExists(atPath: conversation.sourceFile.path))
    }
}
