import Foundation
import SQLite3

/// The rows of OpenCode's `part` table a preview reads: a message's text, tool calls, attachments, and compaction
/// marker, in the order OpenCode shows them. The same SQL decides what an SSH host's mirror copies.
enum OpenCodeTranscriptParts {
    /// Reasoning, step markers, snapshots, patches, retries, subtasks, and agent mentions stay out. Malformed
    /// data has no type, so it is left out instead of failing the query.
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

    /// The previewed parts of one message, and how many bytes of part data were read. `statement` is `query`,
    /// prepared once for all the messages read in one go.
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
