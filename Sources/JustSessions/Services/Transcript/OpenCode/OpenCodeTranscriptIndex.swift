import Foundation
import SQLite3

/// The messages of one OpenCode session that its preview shows, in the order OpenCode shows them: by creation
/// time, then id. After `/undo`, OpenCode hides the undone message and every later one until `/redo` or the next
/// prompt, so they are left out here too, and a note stands in for them.
///
/// Only the messages' ids are read here, from the index OpenCode keeps on its `message` table, without reading any
/// message's data. A page reads the data of its own messages with `OpenCodeTranscriptMessageReader`. Each message is
/// one record, including one whose data is unreadable or isn't a user's or an assistant's message; such a record has no
/// entries.
struct OpenCodeTranscriptIndex {
    let messageIDs: [String]
    let hasUndoneMessages: Bool

    /// The messages, then the note that stands in for undone messages, if any.
    var recordCount: Int { messageIDs.count + (hasUndoneMessages ? 1 : 0) }

    static let messageIDsQuery = "SELECT id FROM message WHERE session_id = ? ORDER BY time_created, id"
    static let undoneMessageQuery = """
        SELECT CASE WHEN json_valid(revert) THEN json_extract(revert, '$.messageID') END FROM session WHERE id = ?
        """

    static func read(sessionID: String, in database: OpaquePointer) throws -> Self {
        let undoneMessageID = try firstUndoneMessageID(sessionID: sessionID, in: database)
        let statement = try OpenCodeDatabase.prepare(messageIDsQuery, in: database)
        defer { sqlite3_finalize(statement) }
        OpenCodeDatabase.bind(sessionID, at: 1, in: statement)
        var messageIDs: [String] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            try Task.checkCancellation()
            if let id = OpenCodeDatabase.text(statement, column: 0) {
                if id == undoneMessageID { return Self(messageIDs: messageIDs, hasUndoneMessages: true) }
                messageIDs.append(id)
            }
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw OpenCodeDatabaseError.unreadable }
        return Self(messageIDs: messageIDs, hasUndoneMessages: false)
    }

    private static func firstUndoneMessageID(sessionID: String, in database: OpaquePointer) throws -> String? {
        let statement = try OpenCodeDatabase.prepare(undoneMessageQuery, in: database)
        defer { sqlite3_finalize(statement) }
        OpenCodeDatabase.bind(sessionID, at: 1, in: statement)
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return OpenCodeDatabase.text(statement, column: 0)
        case SQLITE_DONE: return nil
        default: throw OpenCodeDatabaseError.unreadable
        }
    }
}

/// Reads what the preview needs of one message at a time, with one statement prepared for all the messages read in one
/// go. Finalize it with `close()`.
struct OpenCodeTranscriptMessageReader {
    static let query = "SELECT time_created, \(OpenCodeTranscriptMessage.dataProjection) FROM message WHERE id = ?"

    private let statement: OpaquePointer

    init(in database: OpaquePointer) throws {
        statement = try OpenCodeDatabase.prepare(Self.query, in: database)
    }

    /// Nil for a message that is gone, or whose data is unreadable or isn't a user's or an assistant's message.
    func message(id: String) throws -> OpenCodeTranscriptMessage? {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
        OpenCodeDatabase.bind(id, at: 1, in: statement)
        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            let data = sqlite3_column_blob(statement, 1).map { Data(bytes: $0, count: Int(sqlite3_column_bytes(statement, 1))) }
            return OpenCodeTranscriptMessage(id: id, createdAtMilliseconds: sqlite3_column_int64(statement, 0), data: data)
        case SQLITE_DONE:
            return nil
        default:
            throw OpenCodeDatabaseError.unreadable
        }
    }

    func close() {
        sqlite3_finalize(statement)
    }
}
