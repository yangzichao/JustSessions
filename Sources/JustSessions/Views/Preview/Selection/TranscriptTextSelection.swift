import Foundation

struct TranscriptTextSelectionKey: Hashable, Comparable {
    let entryIndex: Int
    let segmentIndex: Int

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.entryIndex, lhs.segmentIndex) < (rhs.entryIndex, rhs.segmentIndex)
    }
}

struct TranscriptTextSelectionPosition: Hashable, Comparable {
    let key: TranscriptTextSelectionKey
    let offset: Int

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key ? lhs.offset < rhs.offset : lhs.key < rhs.key
    }
}

struct TranscriptTextSelection: Equatable {
    var anchor: TranscriptTextSelectionPosition
    var focus: TranscriptTextSelectionPosition

    var start: TranscriptTextSelectionPosition { min(anchor, focus) }
    var end: TranscriptTextSelectionPosition { max(anchor, focus) }
    var spansSeveralBlocks: Bool { anchor.key != focus.key }

    func range(in key: TranscriptTextSelectionKey, length: Int) -> NSRange {
        let start = start
        let end = end
        guard start.key <= key, key <= end.key else { return NSRange(location: 0, length: 0) }
        let lowerBound = key == start.key ? min(max(0, start.offset), length) : 0
        let upperBound = key == end.key ? min(max(0, end.offset), length) : length
        return NSRange(location: lowerBound, length: max(0, upperBound - lowerBound))
    }
}
