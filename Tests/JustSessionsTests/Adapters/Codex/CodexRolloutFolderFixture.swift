import Foundation
@testable import JustSessions

/// A Codex home folder with rollout files, for adapter tests. The test calls `remove()`.
struct CodexRolloutFolderFixture {
    let root: URL
    let codexDirectory: URL
    let sessionsDirectory: URL

    init() throws {
        root = try makeTemporaryDirectory()
        codexDirectory = root.appendingPathComponent(".codex")
        sessionsDirectory = codexDirectory.appendingPathComponent("sessions/2026/09/24")
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func writeRollout(named fileName: String, lines: [String]) throws -> URL {
        let file = sessionsDirectory.appendingPathComponent(fileName)
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// A rollout whose first line is the `session_meta` line the adapter needs, naming the session and its folder.
    @discardableResult
    func writeRollout(sessionID: String, projectPath: String = "/Users/me/app", laterLines: [String] = []) throws -> URL {
        try writeRollout(
            named: "rollout-2026-09-24T10-00-00-\(sessionID).jsonl",
            lines: [#"{"type":"session_meta","payload":{"id":"\#(sessionID)","cwd":"\#(projectPath)"}}"#] + laterLines
        )
    }

    func writeIndex(lines: [String]) throws {
        let indexFile = codexDirectory.appendingPathComponent("session_index.jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: indexFile, atomically: true, encoding: .utf8)
    }

    func discover() throws -> [Conversation] {
        try CodexAdapter(codexDirectory: codexDirectory).discover()
    }
}
