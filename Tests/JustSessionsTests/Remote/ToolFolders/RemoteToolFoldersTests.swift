import Foundation
import Testing
@testable import JustSessions

struct RemoteToolFoldersTests {
    static let custom = RemoteToolFolders(
        claude: "/data/my claude",
        codex: "/home/me/.codex",
        antigravity: ".gemini/antigravity-cli",
        kiro: "/opt/kiro/sessions/cli",
        pi: ".pi/agent/sessions"
    )

    @Test func rsyncQuotesOnlyAPathTheHostsShellWouldSplit() {
        #expect(RemoteToolFolders.standard.rsyncSource(host: "devbox", provider: .claude) == "devbox:.claude/")
        #expect(Self.custom.rsyncSource(host: "devbox", provider: .codex) == "devbox:/home/me/.codex/")
        #expect(Self.custom.rsyncSource(host: "devbox", provider: .claude) == "devbox:'/data/my claude'/")
    }

    @Test func aScriptFindsARelativeFolderInTheHome() throws {
        let script = "printf '%s|%s' " + Self.custom.shellPath(for: .pi) + " " + Self.custom.shellPath(for: .claude)
        let result = try #require(BoundedProcessRunner.result(
            ofExecutable: "/bin/sh", arguments: ["-c", script], environment: ["HOME": "/home/me"], timeout: 10
        ))

        #expect(result.output == "/home/me/.pi/agent/sessions|/data/my claude")
    }

    @Test func theMirrorKeepsTheFoldersOfItsLastCopy() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = RemoteSessionMirror(cacheRoot: root, sourceHomeOverride: root.path, toolFoldersLookup: { _ in Self.custom })

        #expect(mirror.savedToolFolders(host: "devbox") == .standard)
        #expect(try mirror.lookUpToolFolders(host: "devbox") == Self.custom)
        #expect(mirror.savedToolFolders(host: "devbox") == Self.custom)
        #expect(mirror.savedToolFolders(host: "other") == .standard)

        mirror.removeMirror(host: "devbox")
        #expect(mirror.savedToolFolders(host: "devbox") == .standard)
    }

    /// Copies from a folder outside the stand-in home, as from a host whose `CLAUDE_CONFIG_DIR` points elsewhere.
    @Test func copiesAndDeletesInTheFolderTheHostSet() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let remoteHome = root.appendingPathComponent("remote-home")
        let claudeFolder = root.appendingPathComponent("claude config")
        let projectFolder = claudeFolder.appendingPathComponent("projects/-home-me-paper")
        try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remoteHome.appendingPathComponent(".claude/projects/-home-me-paper"), withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        let transcript = #"{"type":"user","cwd":"/home/me/paper","message":{"content":"Draft intro"}}"# + "\n"
        try transcript.write(to: projectFolder.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)
        // The standard folder holds another session, which isn't the host's.
        try transcript.write(to: remoteHome.appendingPathComponent(".claude/projects/-home-me-paper/\(UUID().uuidString.lowercased()).jsonl"), atomically: true, encoding: .utf8)
        var folders = RemoteToolFolders.standard
        folders.claude = claudeFolder.path
        let mirror = RemoteSessionMirror(
            cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: remoteHome.path, toolFoldersLookup: { [folders] _ in folders }
        )

        let conversations = try RemoteSessionDiscovery(mirror: mirror).discover(host: "devbox")

        #expect(conversations.map(\.sessionID) == [sessionID])
        let deletion = RemoteConversationDeletion(
            runner: RemoteHostCommandRunner { _, command, _ in
                BoundedProcessRunner.result(
                    ofExecutable: "/bin/sh", arguments: ["-c", command],
                    environment: ["HOME": remoteHome.path, "PATH": "/usr/bin:/bin"], includesStandardError: true, timeout: 20
                )
            },
            mirror: mirror
        )
        try deletion.delete(try #require(conversations.first))
        #expect(!FileManager.default.fileExists(atPath: projectFolder.appendingPathComponent("\(sessionID).jsonl").path))
    }
}
