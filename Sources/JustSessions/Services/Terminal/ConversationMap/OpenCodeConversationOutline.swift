import CryptoKit
import Foundation
import SQLite3

/// A map's retained prefix, tail pages, and next proof all belong to one SQLite read snapshot. Earlier messages and
/// parts can change without moving the final anchor, so the proof covers the reader's visible SQL projections.
enum OpenCodeConversationOutline {
    struct Prefix: Sendable {
        let record: Int
        let digest: Data
    }

    struct Read: Sendable {
        let outline: ConversationOutline
        let prefix: Prefix?
        /// Records decoded into entries, excluding the raw columns hashed for prefix validation.
        let decodedRecordCount: Int
    }

    static func read(_ conversation: Conversation, extending previous: ConversationOutline, prefix saved: Prefix?) throws -> Read {
        let database = try OpenCodeDatabase.open(conversation.sourceFile)
        defer { sqlite3_close(database) }
        try OpenCodeDatabase.execute("BEGIN", in: database)
        defer { try? OpenCodeDatabase.execute("ROLLBACK", in: database) }
        let index = try OpenCodeTranscriptIndex.read(sessionID: conversation.sessionID, in: database)
        let limits = ConversationOutlineReader.pageLimits(for: .opencode)
        var hasher = SHA256()
        var hashedRecords = 0
        var decodedRecords = 0
        var builder = ConversationOutlineBuilder()
        var page: TranscriptPage?

        if let resume = ConversationOutlineBuilder.resumePoint(in: previous.blocks), let saved,
           saved.record == resume.record, saved.record <= index.messageIDs.count {
            try hash(0..<saved.record, sessionID: conversation.sessionID, in: database, into: &hasher)
            let checked = hasher
            if Data(checked.finalize()) == saved.digest {
                let tail = try OpenCodeTranscriptPageSource.read(index, in: database,
                    request: .after(resume.record), limits: limits)
                decodedRecords += tail.records.count
                // Every kept block ends before this record. The mutable tail may change or disappear entirely.
                builder = ConversationOutlineBuilder(keeping: previous.blocks[..<resume.keptCount])
                hashedRecords = saved.record
                page = tail
            }
        }
        if page == nil {
            hasher = SHA256()
            page = try OpenCodeTranscriptPageSource.read(index, in: database, request: .first, limits: limits)
            decodedRecords += page!.records.count
        }
        var current = page!
        builder.append(current.entries)
        while current.hasLater {
            try Task.checkCancellation()
            current = try OpenCodeTranscriptPageSource.read(index, in: database,
                request: .after(current.records.upperBound), limits: limits)
            decodedRecords += current.records.count
            builder.append(current.entries)
        }

        let outline = ConversationOutline(blocks: builder.blocks)
        guard let resume = ConversationOutlineBuilder.resumePoint(in: outline.blocks) else {
            return Read(outline: outline, prefix: nil, decodedRecordCount: decodedRecords)
        }
        if resume.record < hashedRecords { hasher = SHA256(); hashedRecords = 0 }
        try hash(hashedRecords..<resume.record, sessionID: conversation.sessionID, in: database, into: &hasher)
        return Read(outline: outline, prefix: Prefix(record: resume.record, digest: Data(hasher.finalize())),
                    decodedRecordCount: decodedRecords)
    }

    /// A single ordered cursor avoids a separate message/part lookup for every retained record. Its projections are
    /// the reader's, so tool output, image URLs, and file diffs are neither kept nor hashed. No Swift JSON objects or
    /// Markdown are built for the retained records.
    private static let prefixQuery = """
        SELECT m.id, m.time_created, m.visible_data, p.id, p.visible_data
        FROM (
            SELECT id, time_created, \(OpenCodeTranscriptMessage.dataProjection) AS visible_data
            FROM message WHERE session_id = ? ORDER BY time_created, id LIMIT ? OFFSET ?
        ) AS m
        LEFT JOIN (
            SELECT message_id, id, \(OpenCodeTranscriptParts.dataProjection) AS visible_data
            FROM part WHERE \(OpenCodeTranscriptParts.typeFilter)
        ) AS p ON p.message_id = m.id
        ORDER BY m.time_created, m.id, p.id
        """

    private static func hash(_ records: Range<Int>, sessionID: String, in database: OpaquePointer, into hasher: inout SHA256) throws {
        guard !records.isEmpty else { return }
        let statement = try OpenCodeDatabase.prepare(prefixQuery, in: database)
        defer { sqlite3_finalize(statement) }
        OpenCodeDatabase.bind(sessionID, at: 1, in: statement)
        sqlite3_bind_int64(statement, 2, Int64(records.count))
        sqlite3_bind_int64(statement, 3, Int64(records.lowerBound))
        var input = DigestInput(hasher: hasher)
        var messageID: String?
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            try Task.checkCancellation()
            let id = OpenCodeDatabase.text(statement, column: 0)
            if id != messageID {
                if messageID != nil { input.append(3) }
                input.append(1)
                input.appendColumn(0, of: statement)
                input.appendInteger(UInt64(bitPattern: sqlite3_column_int64(statement, 1)))
                input.appendColumn(2, of: statement)
                messageID = id
            }
            if sqlite3_column_type(statement, 3) != SQLITE_NULL {
                input.append(2)
                input.appendColumn(3, of: statement)
                input.appendColumn(4, of: statement)
            }
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw OpenCodeDatabaseError.unreadable }
        if messageID != nil { input.append(3) }
        hasher = input.finish()
    }

    /// Length framing distinguishes field boundaries, empty values, and NULL. Batch small fields for CryptoKit;
    /// large columns go directly from SQLite to the hasher, so the temporary buffer stays at most 64 KiB.
    private struct DigestInput {
        static let capacity = 64 << 10
        var hasher: SHA256
        private var pending = Data()

        init(hasher: SHA256) {
            self.hasher = hasher
            pending.reserveCapacity(Self.capacity)
        }

        mutating func append(_ marker: UInt8) {
            if pending.count == Self.capacity { flush() }
            pending.append(marker)
        }

        mutating func appendInteger(_ value: UInt64) {
            var value = value.bigEndian
            withUnsafeBytes(of: &value) { appendBytes($0) }
        }

        mutating func appendColumn(_ column: Int32, of statement: OpaquePointer) {
            let isNull = sqlite3_column_type(statement, column) == SQLITE_NULL
            let count = Int(sqlite3_column_bytes(statement, column))
            appendInteger(isNull ? UInt64.max : UInt64(count))
            if let bytes = sqlite3_column_blob(statement, column), count > 0 {
                appendBytes(UnsafeRawBufferPointer(start: bytes, count: count))
            }
        }

        private mutating func appendBytes(_ bytes: UnsafeRawBufferPointer) {
            if pending.count + bytes.count > Self.capacity { flush() }
            if bytes.count > Self.capacity { hasher.update(bufferPointer: bytes) }
            else { pending.append(contentsOf: bytes) }
        }

        private mutating func flush() {
            if !pending.isEmpty { hasher.update(data: pending); pending.removeAll(keepingCapacity: true) }
        }

        mutating func finish() -> SHA256 {
            flush()
            return hasher
        }
    }
}
