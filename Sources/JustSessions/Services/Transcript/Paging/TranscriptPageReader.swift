import Foundation

enum TranscriptPageReader {
    static func read(
        _ request: TranscriptPageRequest, recordCount: Int, limits: TranscriptPageLimits,
        sourceID: (Int) -> Int, decode: (Int) throws -> ([TranscriptEntry], Int)
    ) throws -> TranscriptPage {
        let backwards: Bool
        var position: Int
        switch request {
        case .first:
            backwards = false
            position = 0
        case .latest:
            backwards = true
            position = recordCount - 1
        case .before(let boundary):
            backwards = true
            position = min(boundary, recordCount) - 1
        case .after(let boundary):
            backwards = false
            position = max(0, boundary)
        case .around(let entryID):
            let sourceRecord = TranscriptPageIdentity.record(for: entryID)
            var lower = 0
            var upper = recordCount
            while lower < upper {
                let middle = lower + (upper - lower) / 2
                if sourceID(middle) < sourceRecord { lower = middle + 1 } else { upper = middle }
            }
            backwards = false
            position = min(lower, max(0, recordCount - 1))
        }
        var lowerBound = min(recordCount, max(0, position + (backwards ? 1 : 0)))
        var upperBound = lowerBound
        var records: [(Int, [TranscriptEntry])] = []
        var entryCount = 0
        var byteCount = 0
        var scannedRecordCount = 0
        while (0..<recordCount).contains(position) {
            try Task.checkCancellation()
            let (entries, bytes) = try decode(position)
            records.append((sourceID(position), entries))
            entryCount += entries.count
            byteCount += bytes
            scannedRecordCount += 1
            lowerBound = min(lowerBound, position)
            upperBound = max(upperBound, position + 1)
            position += backwards ? -1 : 1
            if entryCount > 0
                && (entryCount >= limits.targetEntryCount
                    || scannedRecordCount >= limits.maximumRecordCount || byteCount >= limits.targetByteCount)
            {
                break
            }
            if entries.isEmpty { records.removeLast() }
        }
        return TranscriptPage(
            entries: TranscriptPageAssembler.entries(in: records, maximumMergedToolCallCount: limits.maximumMergedToolCallCount),
            records: lowerBound..<upperBound,
            totalRecordCount: recordCount, decodedByteCount: byteCount,
            precedingSpeaker: try speaker(before: lowerBound, limit: limits.maximumRecordCount, decode: decode))
    }

    private static func speaker(before position: Int, limit: Int, decode: (Int) throws -> ([TranscriptEntry], Int)) throws -> Int? {
        var record = position - 1
        while record >= 0, position - record <= limit {
            try Task.checkCancellation()
            if let entry = try decode(record).0.last { return TranscriptPageAssembler.speaker(of: entry) }
            record -= 1
        }
        return nil
    }
}
