import Foundation
import SQLite3

@testable import JustSessions

struct AntigravitySessionFixture {
    let configurationDirectory: URL
    let sessionID: String
    let projectPath: String
    let databaseFile: URL

    init(configurationDirectory: URL, sessionID: String = UUID().uuidString.lowercased(), projectPath: String = "/srv/Bob's paper; $dollar")
        throws
    {
        self.configurationDirectory = configurationDirectory
        self.sessionID = sessionID
        self.projectPath = projectPath
        databaseFile = configurationDirectory.appendingPathComponent("conversations/\(sessionID).db")
        try FileManager.default.createDirectory(at: databaseFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let metadata = Self.field(1, Self.field(1, Data(URL(fileURLWithPath: projectPath).absoluteString.utf8)))
        try Self.execute(
            [
                "CREATE TABLE trajectory_meta (cascade_id TEXT)",
                "INSERT INTO trajectory_meta VALUES ('\(sessionID)')",
                "CREATE TABLE trajectory_metadata_blob (data BLOB)",
                "INSERT INTO trajectory_metadata_blob VALUES (x'\(metadata.hex)')",
                "CREATE TABLE steps (idx INTEGER PRIMARY KEY, step_type INTEGER NOT NULL DEFAULT 0, status INTEGER NOT NULL DEFAULT 0, step_payload BLOB)",
                "CREATE TABLE executor_metadata (idx INTEGER PRIMARY KEY, data BLOB)",
            ], at: databaseFile)
        try appendPrompt("Fix the build", index: 0)
    }

    var conversation: Conversation {
        .fixture(provider: .antigravity, sessionID: sessionID, projectPath: projectPath, sourceFile: databaseFile)
    }

    func appendPrompt(
        _ text: String,
        index: Int,
        source: Int = 4,
        status: Int = 3,
        createdAt: Date = Date(timeIntervalSince1970: 1_790_400_000.25)
    ) throws {
        try append(
            Self.stepPayload(status: status, createdAt: createdAt, source: source) + Self.field(19, Self.field(2, Data(text.utf8))),
            type: 14, index: index, status: status)
    }

    /// The step's status is Antigravity's own: 3 once done, 9 while it waits for you to allow it.
    func append(_ payload: Data, type: Int, index: Int, status: Int = 3) throws {
        try Self.execute(
            [
                "INSERT INTO steps (idx, step_type, status, step_payload) VALUES (\(index), \(type), \(status), x'\(payload.hex)')"
            ], at: databaseFile)
    }

    /// A step other than a prompt, such as a model response (15) or a command (132), made at `createdAt`.
    func appendStep(type: Int, index: Int, status: Int = 3, createdAt: Date = Date(timeIntervalSince1970: 1_790_400_001)) throws {
        try append(Self.stepPayload(status: status, createdAt: createdAt), type: type, index: index, status: status)
    }

    /// The row Antigravity adds when a turn ends: how it ended (4 finished, 2 interrupted), how many model calls it
    /// made, the index of its last step, which protobuf leaves out when it is 0, and the execution's id.
    func appendExecution(index: Int, endingAtStep lastStepIndex: Int, termination: Int = 4) throws {
        let metadata =
            Self.integer(1, termination) + Self.integer(2, 1)
            + (lastStepIndex == 0 ? Data() : Self.integer(3, lastStepIndex))
            + Self.field(9, Data(UUID().uuidString.lowercased().utf8))
        try Self.execute(["INSERT INTO executor_metadata VALUES (\(index), x'\(metadata.hex)')"], at: databaseFile)
    }

    private static func stepPayload(status: Int, createdAt: Date, source: Int? = nil) -> Data {
        let seconds = Int(createdAt.timeIntervalSince1970.rounded(.down))
        let nanoseconds = Int(((createdAt.timeIntervalSince1970 - Double(seconds)) * 1_000_000_000).rounded())
        let metadata = field(1, integer(1, seconds) + integer(2, nanoseconds)) + (source.map { integer(3, $0) } ?? Data())
        return integer(4, status) + field(5, metadata)
    }

    func writeIndex() throws {
        let file = configurationDirectory.appendingPathComponent("conversation_summaries.db")
        try Self.execute(
            [
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

extension Data {
    fileprivate var hex: String { map { String(format: "%02x", $0) }.joined() }
}
