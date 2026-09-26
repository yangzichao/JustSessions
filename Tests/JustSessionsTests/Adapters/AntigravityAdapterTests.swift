import Foundation
import SQLite3
import Testing
@testable import JustSessions

struct AntigravityAdapterTests {
    @Test func discoversLocalSessionsWithSummaryAndMetadataFallback() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appendingPathComponent("sample project")
        let conversations = root.appendingPathComponent("conversations")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: conversations, withIntermediateDirectories: true)

        let indexedID = UUID().uuidString.lowercased()
        let unindexedID = UUID().uuidString.lowercased()
        try makeSession(
            at: conversations.appendingPathComponent("\(indexedID).db"),
            sessionID: indexedID,
            projectURI: project.absoluteString,
            firstPrompt: "First indexed prompt"
        )
        try makeSession(
            at: conversations.appendingPathComponent("\(unindexedID).db"),
            sessionID: unindexedID,
            projectURI: project.absoluteString,
            firstPrompt: "First unindexed prompt\nMore detail"
        )
        try execute(
            [
                "CREATE TABLE conversation_summaries (conversation_id TEXT, title TEXT, preview TEXT, workspace_uris TEXT, last_modified_time TEXT, app_data_dir TEXT)",
                "INSERT INTO conversation_summaries VALUES ('\(indexedID)', '', 'Indexed preview', '[\"\(project.absoluteString)\"]', '2026-09-23 10:00:00.123456+00:00', 'antigravity-cli')",
                "INSERT INTO conversation_summaries VALUES ('\(UUID().uuidString)', 'IDE only', '', '[\"\(project.absoluteString)\"]', '2026-09-23 10:00:00+00:00', 'antigravity')",
            ],
            at: root.appendingPathComponent("conversation_summaries.db")
        )

        let adapter = AntigravityAdapter(configurationDirectory: root)
        let found = try adapter.discover()
        #expect(found.count == 2)
        #expect(found.allSatisfy { $0.provider == .antigravity && $0.projectPath == project.path })
        #expect(found.first(where: { $0.sessionID == indexedID })?.suggestedTitle == "Indexed preview")
        #expect(found.first(where: { $0.sessionID == unindexedID })?.suggestedTitle == "First unindexed prompt")
        #expect(adapter.arguments(for: found[0], action: .resume) == ["--conversation", found[0].sessionID])
        #expect(adapter.arguments(for: found[0], action: .new).isEmpty)
        #expect(!ConversationProvider.antigravity.supportsBranchFromLauncher)
        #expect(!ConversationProvider.antigravity.supportsDeletionFromLauncher)
    }

    @Test func ignoresMissingAndMismatchedDatabases() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let conversations = root.appendingPathComponent("conversations")
        try FileManager.default.createDirectory(at: conversations, withIntermediateDirectories: true)
        let filenameID = UUID().uuidString.lowercased()
        try makeSession(
            at: conversations.appendingPathComponent("\(filenameID).db"),
            sessionID: UUID().uuidString.lowercased(),
            projectURI: URL(fileURLWithPath: root.path).absoluteString,
            firstPrompt: "Unrelated"
        )
        try Data("not a database".utf8).write(to: conversations.appendingPathComponent("\(UUID().uuidString).db"))

        #expect(try AntigravityAdapter(configurationDirectory: root).discover().isEmpty)
    }

    private func makeSession(at file: URL, sessionID: String, projectURI: String, firstPrompt: String) throws {
        let metadata = field(1, containing: field(1, containing: Data(projectURI.utf8)))
        let prompt = field(19, containing: field(2, containing: Data(firstPrompt.utf8)))
        try execute(
            [
                "CREATE TABLE trajectory_meta (cascade_id TEXT)",
                "CREATE TABLE trajectory_metadata_blob (data BLOB)",
                "CREATE TABLE steps (idx INTEGER, step_type INTEGER, step_payload BLOB)",
                "INSERT INTO trajectory_meta VALUES ('\(sessionID)')",
                "INSERT INTO trajectory_metadata_blob VALUES (x'\(metadata.hex)')",
                "INSERT INTO steps VALUES (0, 14, x'\(prompt.hex)')",
            ],
            at: file
        )
    }

    private func execute(_ statements: [String], at file: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(file.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "AntigravityAdapterTests", code: 1)
        }
        defer { sqlite3_close(database) }
        for statement in statements {
            guard sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK else {
                throw NSError(domain: "AntigravityAdapterTests", code: 2)
            }
        }
    }

    private func field(_ number: UInt8, containing content: Data) -> Data {
        Data(varint(Int(number) << 3 | 2) + varint(content.count)) + content
    }

    private func varint(_ value: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        var length = value
        repeat {
            var nextByte = UInt8(length & 0x7f)
            length >>= 7
            if length > 0 { nextByte |= 0x80 }
            bytes.append(nextByte)
        } while length > 0
        return bytes
    }
}

private extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
