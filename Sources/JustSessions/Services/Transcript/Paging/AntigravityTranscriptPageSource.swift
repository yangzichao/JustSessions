import Foundation
import SQLite3

enum AntigravityTranscriptPageSource {
    static func read(_ file: URL, request: TranscriptPageRequest, limits: TranscriptPageLimits) throws -> TranscriptPage {
        let database = try AntigravityDatabase.open(file)
        defer { sqlite3_close(database) }
        // A read transaction keeps the lightweight step index and the selected payloads in the same snapshot.
        try AntigravityDatabase.execute("BEGIN", in: database)
        defer { try? AntigravityDatabase.execute("ROLLBACK", in: database) }
        var indexStatement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT idx FROM steps ORDER BY idx", -1, &indexStatement, nil) == SQLITE_OK,
              let indexStatement else { throw AntigravityDatabaseError.unreadable }
        defer { sqlite3_finalize(indexStatement) }
        var recordIDs: [Int] = []
        var result = sqlite3_step(indexStatement)
        while result == SQLITE_ROW {
            try Task.checkCancellation()
            let identifier = sqlite3_column_int64(indexStatement, 0)
            guard identifier >= 0, identifier < Int.max / TranscriptPageIdentity.partsPerRecord else {
                throw AntigravityDatabaseError.unreadable
            }
            recordIDs.append(Int(identifier))
            result = sqlite3_step(indexStatement)
        }
        guard result == SQLITE_DONE else { throw AntigravityDatabaseError.unreadable }
        var payloadStatement: OpaquePointer?
        let sql = "SELECT step_type, CASE WHEN length(step_payload) <= ? THEN step_payload END FROM steps WHERE idx = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &payloadStatement, nil) == SQLITE_OK,
              let payloadStatement else { throw AntigravityDatabaseError.unreadable }
        defer { sqlite3_finalize(payloadStatement) }
        return try TranscriptPageReader.read(request, recordCount: recordIDs.count, limits: limits, sourceID: { recordIDs[$0] }) { position in
            try autoreleasepool {
                sqlite3_reset(payloadStatement)
                sqlite3_bind_int64(payloadStatement, 1, Int64(limits.maximumRecordByteCount))
                sqlite3_bind_int64(payloadStatement, 2, Int64(recordIDs[position]))
                guard sqlite3_step(payloadStatement) == SQLITE_ROW else { throw AntigravityDatabaseError.unreadable }
                guard let payload = AntigravityDatabase.blob(payloadStatement, column: 1) else {
                    return (TranscriptRecordDecoder(provider: .antigravity, maximumTextLength: limits.maximumTextLength).entries(from: nil), 0)
                }
                var builder = TranscriptBuilder(maximumEntryCount: .max, maximumTextLength: limits.maximumTextLength)
                AntigravityTranscriptReader().append(stepType: sqlite3_column_int(payloadStatement, 0), payload: payload, to: &builder)
                return (builder.build().entries, payload.count)
            }
        }
    }
}
