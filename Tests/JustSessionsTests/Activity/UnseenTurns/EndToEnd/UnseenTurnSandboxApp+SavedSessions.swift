import Foundation
import Testing
@testable import JustSessions

/// Sessions saved in the sandbox's home where each tool keeps them, titled by their first prompt.
extension UnseenTurnSandboxApp {
    static let piSessionsFolder = ".pi/agent/sessions"
    static let openCodeDatabaseFile = ".local/share/opencode/opencode.db"

    /// Saves a session as its CLI does with its first prompt, which titles it, and refreshes until it is listed.
    func saveSession(_ title: String, of provider: ConversationProvider) async throws {
        switch provider {
        case .claude:
            try saveClaudeSession(title)
        case .codex:
            try saveCodexSession(title)
        case .pi:
            try PiSessionFolderFixture(sessionsDirectory: sandbox.root.appendingPathComponent(Self.piSessionsFolder))
                .writeSession(id: UUID().uuidString.lowercased(), projectPath: sandbox.project.path, lines: [
                    PiSessionFolderFixture.userMessage(title),
                ])
        case .opencode:
            try saveOpenCodeSession(title)
        case .antigravity, .kiro:
            Issue.record("\(provider) does not tell what it is doing")
            return
        }
        store.refreshThisMac()
        try #require(await sandbox.waitUntil { !self.store.isScanningThisMac && self.listedConversation(title) != nil })
    }

    private func saveClaudeSession(_ title: String) throws {
        let projectFolder = sandbox.root.appendingPathComponent(".claude/projects/sandbox-project")
        try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)
        try #"{"type":"user","cwd":"\#(sandbox.project.path)","message":{"content":"\#(title)"}}"#.appending("\n")
            .write(to: projectFolder.appendingPathComponent("\(UUID().uuidString.lowercased()).jsonl"), atomically: true, encoding: .utf8)
    }

    private func saveCodexSession(_ title: String) throws {
        let sessionID = UUID().uuidString.lowercased()
        let dayFolder = sandbox.root.appendingPathComponent(".codex/sessions/2026/10/08")
        try FileManager.default.createDirectory(at: dayFolder, withIntermediateDirectories: true)
        let lines = [
            #"{"timestamp":"2026-10-08T10:00:00.000Z","type":"session_meta","payload":{"id":"\#(sessionID)","cwd":"\#(sandbox.project.path)"}}"#,
            #"{"timestamp":"2026-10-08T10:00:01.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"\#(title)"}]}}"#,
        ]
        try (lines.joined(separator: "\n") + "\n")
            .write(to: dayFolder.appendingPathComponent("rollout-2026-10-08T10-00-00-\(sessionID).jsonl"), atomically: true, encoding: .utf8)
    }

    /// OpenCode keeps every session in one database, titled once the first prompt is in.
    private func saveOpenCodeSession(_ title: String) throws {
        let databaseFile = sandbox.root.appendingPathComponent(Self.openCodeDatabaseFile)
        let isNewDatabase = !FileManager.default.fileExists(atPath: databaseFile.path)
        try FileManager.default.createDirectory(at: databaseFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let database = try OpenCodeDatabaseFixture(file: databaseFile, createsTables: isNewDatabase)
        let sessionID = "ses_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(26)
        try database.addSession(sessionID, directory: sandbox.project.path, title: title)
    }
}
