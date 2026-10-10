import Foundation
import SQLite3

/// Pages through one session in OpenCode's database. Each record is one message, numbered by its position in the
/// session; OpenCode only adds messages at the end, so the numbers stay put while the session grows. A page reads the
/// data of only its own messages, so a page of a long session costs about as much as one of a short session.
enum OpenCodeTranscriptPageSource {
    static func read(_ file: URL, sessionID: String, request: TranscriptPageRequest, limits: TranscriptPageLimits) throws -> TranscriptPage {
        let database = try OpenCodeDatabase.open(file)
        defer { sqlite3_close(database) }
        // The message list and the parts read for this page come from the same snapshot.
        try OpenCodeDatabase.execute("BEGIN", in: database)
        defer { try? OpenCodeDatabase.execute("ROLLBACK", in: database) }
        let index = try OpenCodeTranscriptIndex.read(sessionID: sessionID, in: database)
        let messages = try OpenCodeTranscriptMessageReader(in: database)
        defer { messages.close() }
        let partsStatement = try OpenCodeDatabase.prepare(OpenCodeTranscriptParts.query, in: database)
        defer { sqlite3_finalize(partsStatement) }
        return try TranscriptPageReader.read(request, recordCount: index.recordCount, limits: limits, sourceID: { $0 }) { position in
            try autoreleasepool {
                var builder = TranscriptBuilder(maximumEntryCount: .max, maximumTextLength: limits.maximumTextLength)
                guard index.messageIDs.indices.contains(position) else {
                    OpenCodeTranscriptReader.appendUndoneMessagesNote(to: &builder)
                    return (builder.build().entries, 0)
                }
                guard let message = try messages.message(id: index.messageIDs[position]) else { return ([], 0) }
                let read = try OpenCodeTranscriptParts.read(messageID: message.id, with: partsStatement)
                OpenCodeTranscriptReader().append(message, parts: read.parts, to: &builder)
                return (builder.build().entries, read.byteCount)
            }
        }
    }
}
