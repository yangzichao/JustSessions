import Foundation

enum TranscriptPiPageIndex {
    /// Pi's active branch needs a metadata pass. Only parent links and offsets survive that pass, never message bodies.
    /// Lines are read a chunk at a time, a line longer than a chunk on its own, rather than with a seek and read each.
    static func records(
        in index: TranscriptFileIndex, handle: FileHandle, limits: TranscriptPageLimits,
        chunkSize: Int = 1 << 20
    ) throws -> [Int] {
        precondition(chunkSize > 0)
        var links: [PiEntryLink] = []
        let decoder = JSONDecoder()
        var record = 0
        while record < index.lineStarts.count {
            try Task.checkCancellation()
            let start = index.byteRange(at: record).lowerBound
            // Losing a parent could select the wrong branch. Fail instead of silently showing another conversation.
            guard index.byteRange(at: record).count <= limits.maximumRecordByteCount else { throw CocoaError(.fileReadTooLarge) }
            // A chunk stops before a line over the limit, so the lines ahead of it are read first, as one at a time would.
            var end = record + 1
            while end < index.lineStarts.count, index.byteRange(at: end).upperBound - start <= UInt64(chunkSize),
                index.byteRange(at: end).count <= limits.maximumRecordByteCount
            { end += 1 }
            try autoreleasepool {
                let byteCount = Int(index.byteRange(at: end - 1).upperBound - start)
                try handle.seek(toOffset: start)
                let chunk = try handle.read(upToCount: byteCount) ?? Data()
                guard chunk.count == byteCount else { throw TranscriptPagingError.sourceChanged }
                for line in record..<end {
                    let range = index.byteRange(at: line)
                    let lower = chunk.startIndex + Int(range.lowerBound - start)
                    var upper = chunk.startIndex + Int(range.upperBound - start)
                    // Trimmed by index: removing bytes from a slice of the shared chunk could copy all of it.
                    while upper > lower, chunk[upper - 1] == 10 || chunk[upper - 1] == 13 { upper -= 1 }
                    if let link = PiEntryLink(line: chunk[lower..<upper], lineIndex: line, decoder: decoder) { links.append(link) }
                }
            }
            record = end
        }
        return PiActiveBranch.entries(in: links).filter(\.mightBeShown).map(\.lineIndex)
    }
}
