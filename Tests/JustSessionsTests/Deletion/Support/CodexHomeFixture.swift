import Foundation

@testable import JustSessions

struct CodexHomeFixture {
    let root: URL
    let codexDirectory: URL
    let sessionsDirectory: URL
    let conversation: Conversation

    init() throws {
        root = try makeTemporaryDirectory()
        codexDirectory = root.appendingPathComponent(".codex")
        sessionsDirectory = codexDirectory.appendingPathComponent("sessions")
        let dayDirectory = sessionsDirectory.appendingPathComponent("2026/09/23")
        try FileManager.default.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        let sourceFile = dayDirectory.appendingPathComponent("rollout-2026-09-23T10-00-00-\(sessionID).jsonl")
        try Self.sessionMetaLine(sessionID: sessionID).write(to: sourceFile, atomically: true, encoding: .utf8)
        conversation = .fixture(provider: .codex, sessionID: sessionID, projectPath: "/example", sourceFile: sourceFile)
    }

    static func sessionMetaLine(sessionID: String) -> String {
        "{\"type\":\"session_meta\",\"payload\":{\"id\":\"\(sessionID)\",\"cwd\":\"/example\"}}\n"
    }

    var sessionFileExists: Bool {
        FileManager.default.fileExists(atPath: conversation.sourceFile.path)
    }

    func delete(_ conversation: Conversation? = nil, runningScript script: String, timeout: TimeInterval = 60) throws {
        let fakeCodex = try writeExecutableScript(script, to: root.appendingPathComponent("codex"))
        try CodexConversationDeletion(codexDirectory: codexDirectory, executableURL: fakeCodex, timeout: timeout)
            .delete(conversation ?? self.conversation)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
