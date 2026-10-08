import Foundation
import SQLite3

/// Reads the sessions in OpenCode's database, opened read-only.
enum OpenCodeSQLiteReader {
    struct Session: Equatable {
        let sessionID: String
        let projectPath: String
        let title: String?
        let updatedAt: Date
        /// The session that started this one as a subagent; nil for a session started on its own.
        var parentSessionID: String? = nil
    }

    /// Archived sessions are left out where the database records archiving.
    static let sessionsQuery = """
        SELECT id, directory, title, time_updated, parent_id FROM session WHERE time_archived IS NULL
        """
    static let sessionsQueryWithoutArchiving = """
        SELECT id, directory, title, time_updated, parent_id FROM session
        """

    static func sessions(in databaseFile: URL) -> [Session] {
        guard FileManager.default.fileExists(atPath: databaseFile.path) else { return [] }
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseFile.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            return []
        }
        defer { sqlite3_close(database) }
        // OpenCode writes while it runs; wait briefly for its lock instead of listing nothing.
        sqlite3_busy_timeout(database, 1_000)

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sessionsQuery, -1, &statement, nil) == SQLITE_OK
            || sqlite3_prepare_v2(database, sessionsQueryWithoutArchiving, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        var sessions: [Session] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let sessionID = textColumn(statement, at: 0),
                  let projectPath = textColumn(statement, at: 1) else { continue }
            sessions.append(Session(
                sessionID: sessionID,
                projectPath: projectPath,
                title: textColumn(statement, at: 2),
                updatedAt: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 3)) / 1_000),
                parentSessionID: textColumn(statement, at: 4)
            ))
        }
        return sessions
    }

    private static func textColumn(_ statement: OpaquePointer?, at index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: text)
    }
}
