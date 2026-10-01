import Foundation
import SQLite3
@testable import JustSessions

struct AntigravitySessionFixture {
    let configurationDirectory: URL
    let sessionID: String
    let projectPath: String
    let databaseFile: URL

    init(configurationDirectory: URL, sessionID: String = UUID().uuidString.lowercased(), projectPath: String = "/srv/Bob's paper; $dollar") throws {
        self.configurationDirectory = configurationDirectory
        self.sessionID = sessionID
        self.projectPath = projectPath
        databaseFile = configurationDirectory.appendingPathComponent("conversations/\(sessionID).db")
        try FileManager.default.createDirectory(at: databaseFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let metadata = Self.field(1, Self.field(1, Data(URL(fileURLWithPath: projectPath).absoluteString.utf8)))
        try Self.execute([
            "CREATE TABLE trajectory_meta (cascade_id TEXT)",
            "INSERT INTO trajectory_meta VALUES ('\(sessionID)')",
            "CREATE TABLE trajectory_metadata_blob (data BLOB)",
            "INSERT INTO trajectory_metadata_blob VALUES (x'\(metadata.hex)')",
            "CREATE TABLE steps (idx INTEGER PRIMARY KEY, step_type INTEGER, step_payload BLOB)",
        ], at: databaseFile)
        try appendPrompt("Fix the build", index: 0)
    }

    var conversation: Conversation {
        .fixture(provider: .antigravity, sessionID: sessionID, projectPath: projectPath, sourceFile: databaseFile)
    }

    func appendPrompt(_ text: String, index: Int, source: Int = 4, status: Int = 3) throws {
        let metadata = Self.field(1, Self.integer(1, 1_790_400_000) + Self.integer(2, 250_000_000)) + Self.integer(3, source)
        let payload = Self.integer(4, status) + Self.field(5, metadata) + Self.field(19, Self.field(2, Data(text.utf8)))
        try append(payload, type: 14, index: index)
    }

    func append(_ payload: Data, type: Int, index: Int) throws {
        try Self.execute(["INSERT INTO steps VALUES (\(index), \(type), x'\(payload.hex)')"], at: databaseFile)
    }

    func writeIndex() throws {
        let file = configurationDirectory.appendingPathComponent("conversation_summaries.db")
        try Self.execute([
            "CREATE TABLE IF NOT EXISTS conversation_summaries (conversation_id TEXT, title TEXT, preview TEXT, workspace_uris TEXT, last_modified_time TEXT, app_data_dir TEXT)",
            "INSERT INTO conversation_summaries VALUES ('\(sessionID)', 'Build fix', '', '[]', '2026-10-01 12:00:00+00:00', 'antigravity-cli')",
        ], at: file)
    }

    static func execute(_ statements: [String], at file: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(file.path, &database) == SQLITE_OK, let database else { throw AntigravityDatabaseError.unreadable }
        defer { sqlite3_close(database) }
        for statement in statements { try AntigravityDatabase.execute(statement, in: database) }
    }

    static func field(_ number: Int, _ value: Data) -> Data {
        Data(varint(number << 3 | 2) + varint(value.count)) + value
    }

    static func integer(_ number: Int, _ value: Int) -> Data { Data(varint(number << 3) + varint(value)) }

    private static func varint(_ value: Int) -> [UInt8] {
        var value = value
        var result: [UInt8] = []
        repeat {
            var byte = UInt8(value & 127)
            value >>= 7
            if value > 0 { byte |= 128 }
            result.append(byte)
        } while value > 0
        return result
    }
}

private extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
