import Foundation
import SQLite3

/// An OpenCode database with the tables JustSessions reads, plus the account and credential tables that must
/// never leave an SSH host. Columns match OpenCode's migrations; ones JustSessions never reads are left out.
struct OpenCodeDatabaseFixture {
    let file: URL

    /// Without `createsTables`, the file is left for the test to set up, as an older OpenCode would have.
    init(file: URL, createsTables: Bool = true) throws {
        self.file = file
        guard createsTables else { return }
        try execute("""
            CREATE TABLE session (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, parent_id TEXT, slug TEXT NOT NULL,
                directory TEXT NOT NULL, title TEXT NOT NULL, version TEXT NOT NULL, revert TEXT,
                time_created INTEGER NOT NULL, time_updated INTEGER NOT NULL, time_archived INTEGER);
            CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, time_created INTEGER NOT NULL,
                time_updated INTEGER NOT NULL, data TEXT NOT NULL);
            CREATE INDEX message_session_time_created_id_idx ON message (session_id, time_created, id);
            CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT NOT NULL, session_id TEXT NOT NULL,
                time_created INTEGER NOT NULL, time_updated INTEGER NOT NULL, data TEXT NOT NULL);
            CREATE INDEX part_message_id_id_idx ON part (message_id, id);
            CREATE TABLE account (id TEXT PRIMARY KEY, email TEXT, access_token TEXT, refresh_token TEXT);
            CREATE TABLE credential (id TEXT PRIMARY KEY, value TEXT);
            INSERT INTO account VALUES ('acc_1', 'me@example.com', 'secret-access-token', 'secret-refresh-token');
            INSERT INTO credential VALUES ('cred_1', 'secret-credential');
            """)
    }

    func addSession(
        _ id: String,
        directory: String = "/Users/me/app",
        title: String = "Fix login",
        parentID: String? = nil,
        updatedAt: Int64 = 1_790_000_000_000,
        archivedAt: Int64? = nil,
        revert: [String: Any]? = nil
    ) throws {
        try execute(
            "INSERT INTO session VALUES (?, 'prj_1', ?, 'slug', ?, ?, '1.18.34', ?, ?, ?, ?)",
            [id, parentID, directory, title, try revert.map(Self.json), updatedAt, updatedAt, archivedAt]
        )
    }

    func addMessage(_ id: String, session: String, createdAt: Int64, data: [String: Any]) throws {
        try addMessage(id, session: session, createdAt: createdAt, rawData: Self.json(data))
    }

    func addMessage(_ id: String, session: String, createdAt: Int64, rawData: String) throws {
        try execute("INSERT INTO message VALUES (?, ?, ?, ?, ?)", [id, session, createdAt, createdAt, rawData])
    }

    func addPart(_ id: String, message: String, session: String, data: [String: Any]) throws {
        try execute("INSERT INTO part VALUES (?, ?, ?, 1, 1, ?)", [id, message, session, try Self.json(data)])
    }

    func addUserPrompt(_ messageID: String, session: String, createdAt: Int64, text: String) throws {
        try addMessage(messageID, session: session, createdAt: createdAt, data: ["role": "user", "summary": ["diffs": []]])
        try addPart("prt_\(messageID)_text", message: messageID, session: session, data: ["type": "text", "text": text])
    }

    func addAssistantReply(_ messageID: String, session: String, createdAt: Int64, text: String) throws {
        try addMessage(messageID, session: session, createdAt: createdAt, data: ["role": "assistant"])
        try addPart("prt_\(messageID)_text", message: messageID, session: session, data: ["type": "text", "text": text])
    }

    func count(_ query: String) throws -> Int {
        let database = try open()
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw failure(database, query)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw failure(database, query) }
        return Int(sqlite3_column_int64(statement, 0))
    }

    /// Adds prompts numbered from zero in one transaction, which is much faster than adding them one at a time.
    func addUserPrompts(_ texts: [String], session: String) throws {
        let database = try open()
        defer { sqlite3_close(database) }
        try run("BEGIN", in: database)
        for (index, text) in texts.enumerated() {
            let messageID = String(format: "msg_%06d", index)
            try run("INSERT INTO message VALUES (?, ?, ?, ?, ?)", [messageID, session, Int64(index), Int64(index), try Self.json(["role": "user"])], in: database)
            try run("INSERT INTO part VALUES (?, ?, ?, 1, 1, ?)", ["prt_\(messageID)", messageID, session, try Self.json(["type": "text", "text": text])], in: database)
        }
        try run("COMMIT", in: database)
    }

    /// Adds messages and their parts in one transaction, with their data as JSON text, for sessions too long to add one
    /// row at a time.
    func addRows(
        messages: [(id: String, session: String, createdAt: Int64, data: String)],
        parts: [(id: String, message: String, session: String, data: String)]
    ) throws {
        let database = try open()
        defer { sqlite3_close(database) }
        try run("BEGIN", in: database)
        for message in messages {
            try run("INSERT INTO message VALUES (?, ?, ?, ?, ?)",
                    [message.id, message.session, message.createdAt, message.createdAt, message.data], in: database)
        }
        for part in parts {
            try run("INSERT INTO part VALUES (?, ?, ?, 1, 1, ?)", [part.id, part.message, part.session, part.data], in: database)
        }
        try run("COMMIT", in: database)
    }

    func execute(_ sql: String, _ values: [Any?] = []) throws {
        let database = try open()
        defer { sqlite3_close(database) }
        try run(sql, values, in: database)
    }

    private func run(_ sql: String, _ values: [Any?] = [], in database: OpaquePointer) throws {
        guard !values.isEmpty else {
            guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw failure(database, sql) }
            return
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw failure(database, sql)
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case let text as String: sqlite3_bind_text(statement, index, text, -1, transient)
            case let number as Int64: sqlite3_bind_int64(statement, index, number)
            default: sqlite3_bind_null(statement, index)
            }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure(database, sql) }
    }

    private func open() throws -> OpaquePointer {
        var database: OpaquePointer?
        guard sqlite3_open(file.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "OpenCodeDatabaseFixture", code: 1)
        }
        return database
    }

    private func failure(_ database: OpaquePointer, _ sql: String) -> NSError {
        NSError(domain: "OpenCodeDatabaseFixture", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "\(String(cString: sqlite3_errmsg(database))): \(sql)",
        ])
    }

    private static func json(_ object: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self)
    }
}
