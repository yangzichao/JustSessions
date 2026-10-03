import Foundation
import SQLite3

/// The messages of one OpenCode session that its preview shows, in the order OpenCode shows them: by creation
/// time, then id. After `/undo`, OpenCode hides the undone message and every later one until `/redo` or the next
/// prompt, so they are left out here too, and a note stands in for them.
struct OpenCodeTranscriptIndex {
    let messages: [OpenCodeTranscriptMessage]
    let hasUndoneMessages: Bool

    /// The messages, then the note that stands in for undone messages, if any.
    var recordCount: Int { messages.count + (hasUndoneMessages ? 1 : 0) }

    static let messagesQuery = """
        SELECT id, time_created, \(OpenCodeTranscriptMessage.dataProjection) FROM message
        WHERE session_id = ? ORDER BY time_created, id
        """
    static let undoneMessageQuery = """
        SELECT CASE WHEN json_valid(revert) THEN json_extract(revert, '$.messageID') END FROM session WHERE id = ?
        """

    static func read(sessionID: String, in database: OpaquePointer) throws -> Self {
        let undoneMessageID = try firstUndoneMessageID(sessionID: sessionID, in: database)
        let statement = try OpenCodeDatabase.prepare(messagesQuery, in: database)
        defer { sqlite3_finalize(statement) }
        OpenCodeDatabase.bind(sessionID, at: 1, in: statement)
        var messages: [OpenCodeTranscriptMessage] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            try Task.checkCancellation()
            guard let id = OpenCodeDatabase.text(statement, column: 0) else {
                result = sqlite3_step(statement)
                continue
            }
            if id == undoneMessageID { return Self(messages: messages, hasUndoneMessages: true) }
            let data = sqlite3_column_blob(statement, 2).map { Data(bytes: $0, count: Int(sqlite3_column_bytes(statement, 2))) }
            if let message = OpenCodeTranscriptMessage(id: id, createdAtMilliseconds: sqlite3_column_int64(statement, 1), data: data) {
                messages.append(message)
            }
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw OpenCodeDatabaseError.unreadable }
        return Self(messages: messages, hasUndoneMessages: false)
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
