import Foundation
@testable import JustSessions

/// A Claude Code configuration folder holding one project folder, for adapter tests. The test calls `remove()`.
struct ClaudeProjectFolderFixture {
    let root: URL
    let configurationDirectory: URL
    let projectDirectory: URL

    init() throws {
        root = try makeTemporaryDirectory()
        configurationDirectory = root.appendingPathComponent(".claude")
        projectDirectory = configurationDirectory.appendingPathComponent("projects/-Users-me-app")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func writeTranscript(_ sessionID: String, lines: [String]) throws -> URL {
        let file = projectDirectory.appendingPathComponent("\(sessionID).jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    func writeIndex(_ json: String) throws {
        try json.write(to: projectDirectory.appendingPathComponent("sessions-index.json"), atomically: true, encoding: .utf8)
    }

    func discover() throws -> [Conversation] {
        try ClaudeAdapter(configurationDirectory: configurationDirectory).discover()
    }

    func discoveredConversationsBySessionID() throws -> [String: Conversation] {
        Dictionary(uniqueKeysWithValues: try discover().map { ($0.sessionID, $0) })
    }
}
