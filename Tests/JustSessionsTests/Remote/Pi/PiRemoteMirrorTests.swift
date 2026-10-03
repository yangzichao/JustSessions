import Foundation
import Testing
@testable import JustSessions

struct PiRemoteMirrorTests {
    @Test func mirrorsOnlyTopLevelSessionFilesAndReadsTheirPreviewWithoutCopyingExtensionData() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let remoteHome = root.appendingPathComponent("remote-home")
        let sessionsDirectory = remoteHome.appendingPathComponent(".pi/agent/sessions")
        let fixture = PiSessionFolderFixture(sessionsDirectory: sessionsDirectory)
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try fixture.writeSession(
            id: sessionID,
            projectPath: "/home/me/paper",
            lines: [PiSessionFolderFixture.userMessage("Fix the build"), PiSessionFolderFixture.sessionName("Build fix")]
        )
        let projectFolder = sessionFile.deletingLastPathComponent()
        let companionFolder = sessionFile.deletingPathExtension()
        let nestedFiles = [
            companionFolder.appendingPathComponent("\(UUID().uuidString.lowercased())/run-1/session.jsonl"),
            companionFolder.appendingPathComponent("forks/2026-09-30T11-00-00-000Z_\(UUID().uuidString.lowercased()).jsonl"),
            projectFolder.appendingPathComponent("subagent-artifacts/run_transcript.jsonl"),
        ]
        for nestedFile in nestedFiles {
            try FileManager.default.createDirectory(at: nestedFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: sessionFile, to: nestedFile)
        }
        try "private settings".write(to: remoteHome.appendingPathComponent(".pi/agent/settings.json"), atomically: true, encoding: .utf8)
        try "private auth".write(to: remoteHome.appendingPathComponent(".pi/agent/auth.json"), atomically: true, encoding: .utf8)
        try "not a session".write(to: projectFolder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        let mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: remoteHome.path)
        let discovery = RemoteSessionDiscovery(mirror: mirror)

        let conversations = try discovery.discover(host: "devbox")

        let conversation = try #require(conversations.first)
        #expect(conversations.count == 1)
        #expect(conversation.provider == .pi)
        #expect(conversation.sessionID == sessionID)
        #expect(conversation.host == .ssh("devbox"))
        #expect(conversation.projectDirectoryKey == "ssh://devbox/home/me/paper")
        #expect(conversation.suggestedTitle == "Build fix")
        let transcript = try await TranscriptLoader.load(conversation)
        #expect(transcript.entries.first?.content == .userMessage("Fix the build"))
        let mirroredProjectFolder = mirror.mirrorDirectory(host: "devbox", provider: .pi)
            .appendingPathComponent(projectFolder.lastPathComponent)
        #expect(try FileManager.default.contentsOfDirectory(atPath: mirroredProjectFolder.path) == [sessionFile.lastPathComponent])
        #expect(try FileManager.default.contentsOfDirectory(atPath: mirroredProjectFolder.deletingLastPathComponent().path)
            == [projectFolder.lastPathComponent])

        // A session deleted on the host disappears from the mirror on the next copy.
        try FileManager.default.removeItem(at: sessionFile)
        #expect(try discovery.discover(host: "devbox").isEmpty)
        #expect(!FileManager.default.fileExists(atPath: conversation.sourceFile.path))
    }

    @Test func copiesOnlyFoldersAndTheSessionFilesDirectlyInThem() {
        #expect(RemoteSessionMirror.includedPatterns(for: .pi) == ["/*/", "/*/*.jsonl"])
        #expect(RemoteSessionMirror.remoteFolder(for: .pi) == ".pi/agent/sessions")
        #expect(RemoteSessionMirror.rsyncArguments(for: .pi, source: "devbox:.pi/agent/sessions/", destination: "/cache/pi/").suffix(5)
            == ["--include=/*/", "--include=/*/*.jsonl", "--exclude=*", "devbox:.pi/agent/sessions/", "/cache/pi/"])
    }
}
