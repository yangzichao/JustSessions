import Foundation
import SQLite3

struct AntigravityTranscriptReader {
    var maximumEntryCount = 2_000
    var maximumTextLength = 12_000

    func read(_ file: URL) throws -> TranscriptContent {
        let database = try AntigravityDatabase.open(file)
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT step_type, step_payload FROM steps ORDER BY idx", -1, &statement, nil) == SQLITE_OK,
              let statement else { throw AntigravityDatabaseError.unreadable }
        defer { sqlite3_finalize(statement) }
        var builder = TranscriptBuilder(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength)
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            try Task.checkCancellation()
            if let payload = AntigravityDatabase.blob(statement, column: 1) {
                append(stepType: sqlite3_column_int(statement, 0), payload: payload, to: &builder)
            }
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw AntigravityDatabaseError.unreadable }
        return builder.build()
    }

    private func append(stepType: Int32, payload: Data, to builder: inout TranscriptBuilder) {
        let status = AntigravityProtobuf.integer(in: payload, field: 4)
        guard status != 4, status != 5 else { return } // Invalid or cleared by rewind/compaction.
        let timestamp = AntigravityTranscriptTimestamp.date(in: payload)
        switch stepType {
        case 14:
            let metadata = AntigravityProtobuf.bytes(in: payload, at: [5])
            let source = metadata.flatMap { AntigravityProtobuf.integer(in: $0, field: 3) }
            guard source == nil || source == 4 else { return } // USER_EXPLICIT; omit injected context.
            if let text = AntigravityProtobuf.text(in: payload, at: [19, 2])
                ?? AntigravityProtobuf.text(in: payload, at: [19, 1]) {
                builder.append(.userMessage, text: text, timestamp: timestamp)
            }
        case 15:
            if let response = AntigravityProtobuf.bytes(in: payload, at: [20]) {
                let text = AntigravityProtobuf.text(in: response, at: [8])
                    ?? AntigravityProtobuf.text(in: response, at: [1]) ?? ""
                builder.append(.assistantMessage, text: text, timestamp: timestamp)
                for toolCall in AntigravityProtobuf.repeatedBytes(in: response, field: 7) {
                    guard let name = AntigravityProtobuf.text(in: toolCall, at: [2]), !name.isEmpty else { continue }
                    let json = AntigravityProtobuf.text(in: toolCall, at: [3]) ?? ""
                    let arguments = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
                    builder.append(.toolCall, text: ToolCallSummary.summary(toolName: name, arguments: arguments), timestamp: timestamp)
                }
            }
        default: break // Tool results, thinking and internal bookkeeping remain hidden.
        }
    }
}
