import Foundation
import Testing
@testable import JustSessions

/// A host's sessions are copied one tool after another, and each tool's are listed before the next copy starts.
struct RemoteSessionToolByToolDiscoveryTests {
    @Test func listsEachToolsSessionsBeforeCopyingTheNext() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let remoteHome = root.appendingPathComponent("remote-home")
        let claudeProject = remoteHome.appendingPathComponent(".claude/projects/-home-me-paper")
        let codexDay = remoteHome.appendingPathComponent(".codex/sessions/2026/09/24")
        try FileManager.default.createDirectory(at: claudeProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexDay, withIntermediateDirectories: true)
        let claudeID = UUID().uuidString
        let codexID = UUID().uuidString
        try #"{"type":"user","cwd":"/home/me/paper","message":{"content":"Draft intro"}}"#
            .appending("\n")
            .write(to: claudeProject.appendingPathComponent("\(claudeID).jsonl"), atomically: true, encoding: .utf8)
        try #"{"type":"session_meta","payload":{"id":"\#(codexID)","cwd":"/home/me/api"}}"#
            .appending("\n")
            .write(to: codexDay.appendingPathComponent("rollout-2026-09-24T10-00-00-\(codexID).jsonl"), atomically: true, encoding: .utf8)
        let mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: remoteHome.path)
        let codexMirror = mirror.mirrorDirectory(host: "devbox", provider: .codex)
        let log = CopyLog()

        try await RemoteSessionDiscovery(mirror: mirror).discoverToolByTool(
            host: "devbox",
            copying: { step in await log.append("copying \(step.provider.rawValue) \(step.number)/\(step.count)") },
            copied: { step, conversations in
                await log.append("copied \(step.provider.rawValue): \(conversations.map(\.sessionID).sorted())")
                if step.provider == .claude {
                    await log.append("Codex copied yet: \(FileManager.default.fileExists(atPath: codexMirror.path))")
                }
                #expect(conversations.allSatisfy { $0.provider == step.provider && $0.host == .ssh("devbox") })
            }
        )

        #expect(await log.entries == [
            "copying Claude Code 1/6", "copied Claude Code: [\"\(claudeID)\"]", "Codex copied yet: false",
            "copying Codex 2/6", "copied Codex: [\"\(codexID)\"]",
            "copying Antigravity 3/6", "copied Antigravity: []",
            "copying Kiro CLI 4/6", "copied Kiro CLI: []",
            "copying OpenCode 5/6", "copied OpenCode: []",
            "copying Pi 6/6", "copied Pi: []",
        ])
        #expect(Set(try RemoteSessionDiscovery(mirror: mirror).readMirror(host: "devbox").map(\.sessionID)) == [claudeID, codexID])
    }
}

private actor CopyLog {
    private(set) var entries: [String] = []

    func append(_ entry: String) {
        entries.append(entry)
    }
}
