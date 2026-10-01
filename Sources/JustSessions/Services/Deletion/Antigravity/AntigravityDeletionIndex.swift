import Foundation
import SQLite3

enum AntigravityDeletionIndex {
    /// Holds the index transaction until all session files have moved successfully.
    static func removingEntry<T>(sessionID: String, configurationDirectory: URL, perform: () throws -> T) throws -> T {
        let index = configurationDirectory.appendingPathComponent("conversation_summaries.db")
        guard FileManager.default.fileExists(atPath: index.path) else { return try perform() }
        let database = try AntigravityDatabase.open(index, writable: true)
        defer { sqlite3_close(database) }
        try AntigravityDatabase.execute("BEGIN IMMEDIATE", in: database)
        do {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database,
                "DELETE FROM conversation_summaries WHERE conversation_id = ? AND app_data_dir = 'antigravity-cli'",
                -1, &statement, nil) == SQLITE_OK, let statement else { throw AntigravityDatabaseError.unreadable }
            let result = sessionID.withCString { text -> Int32 in
                sqlite3_bind_text(statement, 1, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                return sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
            guard result == SQLITE_DONE else { throw AntigravityDatabaseError.unreadable }
            let value = try perform()
            try AntigravityDatabase.execute("COMMIT", in: database)
            return value
        } catch {
            try? AntigravityDatabase.execute("ROLLBACK", in: database)
            throw error
        }
    }
}
