import Foundation
import Testing
@testable import JustSessions

/// Copies from a local folder standing in for the remote home, with the same rsync filters used over SSH.
struct RemoteSessionMirrorTests {
    @Test func mirrorsOnlySessionFilesAndListsThemAsRemote() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let remoteHome = root.appendingPathComponent("remote-home")
        let claudeProject = remoteHome.appendingPathComponent(".claude/projects/-home-me-paper")
        let codexDay = remoteHome.appendingPathComponent(".codex/sessions/2026/09/24")
        try FileManager.default.createDirectory(at: claudeProject.appendingPathComponent("subagents"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexDay, withIntermediateDirectories: true)

        let claudeID = UUID().uuidString
        let codexID = UUID().uuidString
        try #"{"type":"user","cwd":"/home/me/paper","message":{"content":"Draft intro"}}"#
            .appending("\n")
            .write(to: claudeProject.appendingPathComponent("\(claudeID).jsonl"), atomically: true, encoding: .utf8)
        try "{}".write(to: claudeProject.appendingPathComponent("subagents/agent.jsonl"), atomically: true, encoding: .utf8)
        try "{}".write(to: remoteHome.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)
        try #"{"type":"session_meta","payload":{"id":"\#(codexID)","cwd":"/home/me/api"}}"#
            .appending("\n")
            .write(to: codexDay.appendingPathComponent("rollout-2026-09-24T10-00-00-\(codexID).jsonl"), atomically: true, encoding: .utf8)

        let mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: remoteHome.path)
        let discovery = RemoteSessionDiscovery(mirror: mirror)
        let conversations = try discovery.discover(host: "devbox")

        #expect(Set(conversations.map(\.sessionID)) == [claudeID, codexID])
        #expect(conversations.allSatisfy { $0.host == .ssh("devbox") })
        #expect(conversations.first { $0.provider == .claude }?.suggestedTitle == "Draft intro")
        #expect(conversations.first { $0.provider == .codex }?.projectDirectoryKey == "ssh://devbox/home/me/api")

        let claudeMirror = mirror.mirrorDirectory(host: "devbox", provider: .claude)
        #expect(!FileManager.default.fileExists(atPath: claudeMirror.appendingPathComponent("settings.json").path))
        #expect(!FileManager.default.fileExists(atPath: claudeMirror.appendingPathComponent("projects/-home-me-paper/subagents").path))

        // A session deleted on the host disappears from the mirror on the next copy.
        try FileManager.default.removeItem(at: claudeProject.appendingPathComponent("\(claudeID).jsonl"))
        #expect(try discovery.discover(host: "devbox").map(\.sessionID) == [codexID])
    }

    @Test func hostWithoutAToolFolderListsNothingForIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let remoteHome = root.appendingPathComponent("remote-home")
        try FileManager.default.createDirectory(at: remoteHome, withIntermediateDirectories: true)

        let mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: remoteHome.path)
        #expect(try RemoteSessionDiscovery(mirror: mirror).discover(host: "devbox").isEmpty)
    }

    @Test func hostNamesBecomeSafeFolderNames() {
        #expect(RemoteSessionMirror.directoryName(forHost: "me@devbox.example.com") == "me@devbox.example.com")
        #expect(RemoteSessionMirror.directoryName(forHost: "a:b") == "a_b")
    }
}
