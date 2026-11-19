import Foundation
import SQLite3

enum OpenCodeTranscriptParts {
    static let typeFilter = """
        (CASE WHEN json_valid(data) THEN json_extract(data, '$.type') END) IN ('text', 'tool', 'file', 'compaction')
        """

    /// A part's data without what a preview never shows and what can run to megabytes: a tool's output,
    /// attachments, and metadata, and a file's contents, which an attached image keeps inline as a data URL.
    static let dataProjection = """
        CASE json_extract(data, '$.type')
            WHEN 'tool' THEN json_remove(data, '$.state.output', '$.state.metadata', '$.state.attachments', '$.metadata')
            WHEN 'file' THEN json_remove(data, '$.url')
            ELSE data
        END
        """

    static let query = "SELECT \(dataProjection) FROM part WHERE message_id = ? AND \(typeFilter) ORDER BY id"

    static func read(messageID: String, with statement: OpaquePointer) throws -> (parts: [[String: Any]], byteCount: Int) {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
        OpenCodeDatabase.bind(messageID, at: 1, in: statement)
        var parts: [[String: Any]] = []
        var byteCount = 0
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            if let bytes = sqlite3_column_blob(statement, 0) {
                let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
                byteCount += data.count
                if let part = ConversationMetadata.object(from: data) { parts.append(part) }
            }
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw OpenCodeDatabaseError.unreadable }
        return (parts, byteCount)
    }
}
