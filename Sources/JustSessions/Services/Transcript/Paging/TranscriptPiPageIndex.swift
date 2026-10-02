import Foundation

enum TranscriptPiPageIndex {
    /// Pi's active branch needs a metadata pass. Only parent links and offsets survive that pass, never message bodies.
    static func records(in index: TranscriptFileIndex, handle: FileHandle, limits: TranscriptPageLimits) throws -> [Int] {
        var links: [PiEntryLink] = []
        let decoder = JSONDecoder()
        for record in index.lineStarts.indices {
            try Task.checkCancellation()
            let link = try autoreleasepool { () throws -> PiEntryLink? in
                guard var data = try index.readRecord(at: record, from: handle, maximumByteCount: limits.maximumRecordByteCount) else {
                    // Losing a parent could select the wrong branch. Fail instead of silently showing another conversation.
                    throw CocoaError(.fileReadTooLarge)
                }
                while data.last == 10 || data.last == 13 { data.removeLast() }
                return PiEntryLink(line: data, lineIndex: record, decoder: decoder)
            }
            if let link { links.append(link) }
        }
        return PiActiveBranch.entries(in: links).filter(\.mightBeShown).map(\.lineIndex)
    }
}
