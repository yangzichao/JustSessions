import Foundation
import SQLite3

enum AntigravityDatabase {
    static func open(_ file: URL, writable: Bool = false) throws -> OpaquePointer {
        var database: OpaquePointer?
        let flags = writable ? SQLITE_OPEN_READWRITE : SQLITE_OPEN_READONLY
        guard sqlite3_open_v2(file.path, &database, flags, nil) == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw AntigravityDatabaseError.unreadable
        }
        sqlite3_busy_timeout(database, 2_000)
        return database
    }

    static func execute(_ sql: String, in database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw AntigravityDatabaseError.unreadable
        }
    }

    static func blob(_ statement: OpaquePointer, column: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, column) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
    }
}

enum AntigravityDatabaseError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        "The Antigravity conversation database could not be read or updated. Close its CLI and try again."
    }
}
