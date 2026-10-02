import Foundation

/// Source record numbers stay stable when new records are appended. Parts of one record have distinct IDs.
enum TranscriptPageIdentity {
    static let partsPerRecord = 1 << 20
    static func entryID(record: Int, part: Int) -> Int { record * partsPerRecord + part }
    static func record(for entryID: Int) -> Int { entryID / partsPerRecord }
}

enum TranscriptPageRequest: Sendable, Equatable {
    case first
    case latest
    case before(Int)
    case after(Int)
    case around(Int)
}

struct TranscriptPage: Sendable {
    let entries: [TranscriptEntry]
    /// Half-open range of source record positions, including records with no visible content.
    let records: Range<Int>
    let totalRecordCount: Int
    let decodedByteCount: Int

    var hasEarlier: Bool { records.lowerBound > 0 }
    var hasLater: Bool { records.upperBound < totalRecordCount }
}

struct TranscriptPageLimits: Sendable {
    var targetEntryCount = 80
    var maximumRecordCount = 256
    var targetByteCount = 1 << 20
    var maximumRecordByteCount = 16 << 20
    var maximumTextLength = 12_000
}

enum TranscriptPagingError: LocalizedError {
    case sourceChanged

    var errorDescription: String? {
        "The session changed while it was being read. Try loading it again."
    }
}
