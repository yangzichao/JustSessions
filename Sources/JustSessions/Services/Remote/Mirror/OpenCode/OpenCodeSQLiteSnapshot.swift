import Foundation
import SQLite3

enum OpenCodeSQLiteSnapshot {
    static func copy(_ source: URL, to destination: URL) throws {
        guard FileManager.default.fileExists(atPath: source.path) else { throw OpenCodeDatabaseError.unreadable }
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI
        guard sqlite3_open_v2(destination.path, &database, flags, nil) == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw OpenCodeDatabaseError.unreadable
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 5_000)
        let attach = try OpenCodeDatabase.prepare("ATTACH DATABASE ? AS source", in: database)
        OpenCodeDatabase.bind(source.absoluteString + "?mode=ro", at: 1, in: attach)
        let attachResult = sqlite3_step(attach)
        sqlite3_finalize(attach)
        guard attachResult == SQLITE_DONE else { throw OpenCodeDatabaseError.unreadable }

        try OpenCodeDatabase.execute("BEGIN", in: database)
        do {
            for alternatives in OpenCodeMirrorSnapshotSteps.steps {
                try run(alternatives, in: database)
            }
            try OpenCodeDatabase.execute("COMMIT", in: database)
        } catch {
            try? OpenCodeDatabase.execute("ROLLBACK", in: database)
            throw error
        }
        try OpenCodeDatabase.execute("DETACH DATABASE source", in: database)
    }

    private static func run(_ alternatives: [String], in database: OpaquePointer) throws {
        for statement in alternatives {
            if sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK { return }
            guard String(cString: sqlite3_errmsg(database)).hasPrefix("no such") else { break }
        }
        throw OpenCodeDatabaseError.unreadable
    }
}
