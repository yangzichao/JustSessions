import Foundation
import Testing

@testable import JustSessions

struct TranscriptTextSelectionTests {
    private static func position(_ entryIndex: Int, _ segmentIndex: Int, _ offset: Int) -> TranscriptTextSelectionPosition {
        TranscriptTextSelectionPosition(key: TranscriptTextSelectionKey(entryIndex: entryIndex, segmentIndex: segmentIndex), offset: offset)
    }

    private static func key(_ entryIndex: Int, _ segmentIndex: Int) -> TranscriptTextSelectionKey {
        TranscriptTextSelectionKey(entryIndex: entryIndex, segmentIndex: segmentIndex)
    }

    /// Keys sort by entry, then by the block's place in it, which is reading order.
    @Test func keysSortInReadingOrder() {
        let keys = [Self.key(2, 0), Self.key(1, 3), Self.key(1, 0), Self.key(10, 1)]
        #expect(keys.sorted() == [Self.key(1, 0), Self.key(1, 3), Self.key(2, 0), Self.key(10, 1)])
    }

    /// The first block is selected from the anchor on, the blocks between it and the focus whole, and the last up to
    /// the focus, whichever way the selection was dragged.
    @Test(arguments: [false, true])
    func coversEachBlockInReadingOrder(isDraggedUpward: Bool) {
        let earlier = Self.position(1, 0, 4)
        let later = Self.position(3, 2, 7)
        let selection =
            isDraggedUpward
            ? TranscriptTextSelection(anchor: later, focus: earlier)
            : TranscriptTextSelection(anchor: earlier, focus: later)

        #expect(selection.spansSeveralBlocks)
        #expect(selection.range(in: Self.key(1, 0), length: 20) == NSRange(location: 4, length: 16))
        #expect(selection.range(in: Self.key(2, 5), length: 30) == NSRange(location: 0, length: 30))
        #expect(selection.range(in: Self.key(3, 2), length: 20) == NSRange(location: 0, length: 7))
        #expect(selection.range(in: Self.key(0, 9), length: 20).length == 0)
        #expect(selection.range(in: Self.key(3, 3), length: 20).length == 0)
    }

    /// A selection inside one block covers the characters between its two ends, clamped to text that got shorter.
    @Test func coversPartOfOneBlock() {
        let selection = TranscriptTextSelection(anchor: Self.position(4, 1, 9), focus: Self.position(4, 1, 2))

        #expect(!selection.spansSeveralBlocks)
        #expect(selection.range(in: Self.key(4, 1), length: 20) == NSRange(location: 2, length: 7))
        #expect(selection.range(in: Self.key(4, 1), length: 5) == NSRange(location: 2, length: 3))
    }
}
