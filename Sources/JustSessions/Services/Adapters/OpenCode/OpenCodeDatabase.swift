import Foundation
import SQLite3

/// Opens OpenCode's database, or its copy in an SSH host's mirror. OpenCode writes while it runs, so each
/// connection waits briefly for its lock.
enum OpenCodeDatabase {
    static func open(_ file: URL, writable: Bool = false) throws -> OpaquePointer {
        guard FileManager.default.fileExists(atPath: file.path) else { throw OpenCodeDatabaseError.unreadable }
        var database: OpaquePointer?
        let flags = writable ? SQLITE_OPEN_READWRITE : SQLITE_OPEN_READONLY
        guard sqlite3_open_v2(file.path, &database, flags, nil) == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw OpenCodeDatabaseError.unreadable
        }
        sqlite3_busy_timeout(database, 2_000)
        return database
    }

    static func execute(_ sql: String, in database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw OpenCodeDatabaseError.unreadable }
    }

    static func prepare(_ sql: String, in database: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw OpenCodeDatabaseError.unreadable
        }
        return statement
    }

    /// Binds text SQLite copies, so `text` need not outlive the call.
    static func bind(_ text: String, at index: Int32, in statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    static func text(_ statement: OpaquePointer, column: Int32) -> String? {
        guard let bytes = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: bytes)
    }

    /// Whether the session is in the database, as a top-level session with that project folder.
    static func containsTopLevelSession(_ sessionID: String, projectPath: String, in file: URL) throws -> Bool {
        let database = try open(file)
        defer { sqlite3_close(database) }
        let statement = try prepare("SELECT directory FROM session WHERE id = ? AND parent_id IS NULL", in: database)
        defer { sqlite3_finalize(statement) }
        bind(sessionID, at: 1, in: statement)
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return text(statement, column: 0) == projectPath
        case SQLITE_DONE: return false
        default: throw OpenCodeDatabaseError.unreadable
        }
    }

    /// Whether the session is in the database as a top-level session, in any project folder.
    static func containsTopLevelSession(_ sessionID: String, in file: URL) throws -> Bool {
        let database = try open(file)
        defer { sqlite3_close(database) }
        let statement = try prepare("SELECT 1 FROM session WHERE id = ? AND parent_id IS NULL", in: database)
        defer { sqlite3_finalize(statement) }
        bind(sessionID, at: 1, in: statement)
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw OpenCodeDatabaseError.unreadable
        }
    }

    /// Whether any row for the session is left, so a deletion can confirm it is gone.
    static func containsSession(_ sessionID: String, in file: URL) throws -> Bool {
        let database = try open(file)
        defer { sqlite3_close(database) }
        let statement = try prepare("SELECT 1 FROM session WHERE id = ?", in: database)
        defer { sqlite3_finalize(statement) }
        bind(sessionID, at: 1, in: statement)
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw OpenCodeDatabaseError.unreadable
        }
    }
}

enum OpenCodeDatabaseError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        "The OpenCode session database could not be read. Try again in a moment."
    }
}
