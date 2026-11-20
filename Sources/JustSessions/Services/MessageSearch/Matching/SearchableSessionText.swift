import Darwin
import Foundation

struct SearchableSessionText: Sendable {
    private struct SegmentPosition: Sendable {
        let entry: Int
        let segment: Int
    }

    private static let segmentSeparatorNoTypedQueryHolds: UInt8 = 0

    let text: SessionMessageText
    private let foldedBytes: [UInt8]
    private let segmentStarts: [Int]
    private let segmentPositions: [SegmentPosition]

    init(_ text: SessionMessageText) {
        self.text = text
        var foldedBytes: [UInt8] = []
        var segmentStarts: [Int] = []
        var segmentPositions: [SegmentPosition] = []
        for (entryIndex, entry) in text.entries.enumerated() {
            for (segmentIndex, segment) in entry.segments.enumerated() {
                segmentStarts.append(foldedBytes.count)
                segmentPositions.append(SegmentPosition(entry: entryIndex, segment: segmentIndex))
                foldedBytes += SessionMessageQuery.folded(segment).utf8
                foldedBytes.append(Self.segmentSeparatorNoTypedQueryHolds)
            }
        }
        self.foldedBytes = foldedBytes
        self.segmentStarts = segmentStarts
        self.segmentPositions = segmentPositions
    }

    func firstMatch(of query: SessionMessageQuery) -> SessionMessageMatch? {
        foldedBytes.withUnsafeBytes { haystack in
            query.foldedBytes.withUnsafeBytes { needle in
                guard let haystackStart = haystack.baseAddress, let needleStart = needle.baseAddress else { return nil }
                var searchStart = 0
                while searchStart < haystack.count,
                    let found = memmem(haystackStart + searchStart, haystack.count - searchStart, needleStart, needle.count)
                {
                    let segmentNumber = segmentNumber(containing: haystackStart.distance(to: UnsafeRawPointer(found)))
                    let position = segmentPositions[segmentNumber]
                    let entry = text.entries[position.entry]
                    let segment = entry.segments[position.segment]
                    if let range = TranscriptTextSearch.firstRange(of: query.text, in: segment) {
                        return SessionMessageMatch(entryID: entry.id, snippet: SessionMessageSnippet(segment: segment, match: range))
                    }
                    searchStart = segmentNumber + 1 < segmentStarts.count ? segmentStarts[segmentNumber + 1] : haystack.count
                }
                return nil
            }
        }
    }

    private func segmentNumber(containing offset: Int) -> Int {
        var lower = 0
        var upper = segmentStarts.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if segmentStarts[middle] <= offset { lower = middle + 1 } else { upper = middle }
        }
        return lower - 1
    }
}
