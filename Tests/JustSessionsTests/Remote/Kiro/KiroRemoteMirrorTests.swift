import Foundation
import Testing
@testable import JustSessions

struct KiroRemoteMirrorTests {
    @Test func mirrorsTheSessionPairAndReadsItsPreviewWithoutCopyingLocksOrSubagentFolders() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let remoteHome = root.appendingPathComponent("remote-home")
        let sessionsDirectory = remoteHome.appendingPathComponent(".kiro/sessions/cli")
        let sessionID = UUID().uuidString.lowercased()
        let fixture = KiroSessionFolderFixture(sessionsDirectory: sessionsDirectory)
        try fixture.writeSession(id: sessionID, projectPath: "/home/me/paper", title: "Build fix", messageLines: KiroTranscriptSamples.lines)
        try fixture.writeSession(id: UUID().uuidString, projectPath: "/home/me/paper", createdReason: "subagent", messageLines: KiroTranscriptSamples.lines)
        try "private lock".write(to: sessionsDirectory.appendingPathComponent("\(sessionID).lock"), atomically: true, encoding: .utf8)
        try "private prompt history".write(to: sessionsDirectory.appendingPathComponent("\(sessionID).history"), atomically: true, encoding: .utf8)
        let subagentDirectory = sessionsDirectory.appendingPathComponent("\(sessionID)/subagents")
        try FileManager.default.createDirectory(at: subagentDirectory, withIntermediateDirectories: true)
        try "{}".write(to: subagentDirectory.appendingPathComponent("child.jsonl"), atomically: true, encoding: .utf8)
        try "private settings".write(to: remoteHome.appendingPathComponent(".kiro/settings.json"), atomically: true, encoding: .utf8)
        let mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: remoteHome.path)
        let discovery = RemoteSessionDiscovery(mirror: mirror)

        let conversations = try discovery.discover(host: "devbox")

        let conversation = try #require(conversations.first)
        #expect(conversations.count == 1)
        #expect(conversation.provider == .kiro)
        #expect(conversation.sessionID == sessionID)
        #expect(conversation.host == .ssh("devbox"))
        #expect(conversation.suggestedTitle == "Build fix")
        #expect(conversation.supportsDeletionFromLauncher)
        guard case .loaded(let transcript) = try await TranscriptLoader.load(conversation) else {
            Issue.record("A mirrored Kiro conversation should have a preview")
            return
        }
        #expect(transcript.entries.first?.content == .userMessage("Fix the build"))
        let mirroredDirectory = mirror.mirrorDirectory(host: "devbox", provider: .kiro)
        for excludedPath in ["\(sessionID).lock", "\(sessionID).history", sessionID, "settings.json"] {
            #expect(!FileManager.default.fileExists(atPath: mirroredDirectory.appendingPathComponent(excludedPath).path))
        }

        try FileManager.default.removeItem(at: sessionsDirectory.appendingPathComponent("\(sessionID).json"))
        try FileManager.default.removeItem(at: sessionsDirectory.appendingPathComponent("\(sessionID).jsonl"))
        #expect(try discovery.discover(host: "devbox").isEmpty)
        #expect(!FileManager.default.fileExists(atPath: conversation.sourceFile.path))
    }
}
