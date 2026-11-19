import CoreGraphics
import Testing

@testable import JustSessions

@MainActor
struct ConversationMapLayoutTests {
    private static func block(
        _ record: Int, _ kind: ConversationOutline.Block.Kind, widths: [UInt8] = [40], part: Int = 0,
        toolCalls: Int = 0
    ) -> ConversationOutline.Block {
        ConversationOutline.Block(
            entryID: TranscriptPageIdentity.entryID(record: record, part: part), lastRecord: record, kind: kind,
            timestamp: nil, snippet: "Block \(record)", lineWidths: widths, toolCallCount: toolCalls)
    }

    private static func layout(_ outline: ConversationOutline, height: CGFloat) -> ConversationMapLayout {
        ConversationMapLayout(rowCount: outline.rowCount, height: height, naturalPitch: 3, verticalInset: 6)
    }

    private static func bookmark(_ letter: String, at record: Int, part: Int = 0) -> MessageBookmark {
        MessageBookmark(letter: letter, entryID: TranscriptPageIdentity.entryID(record: record, part: part), kind: .assistant, snippet: "")
    }

    @Test func aShortConversationDrawsAtNaturalPitchFromTheTop() {
        let outline = ConversationOutline(blocks: [Self.block(0, .user, widths: [10, 20]), Self.block(1, .assistant, widths: [80])])
        let layout = Self.layout(outline, height: 700)

        let bars = layout.bars(for: outline, pixel: 0.5)

        #expect(layout.pitch == 3)
        #expect(bars.first?.minY == 6)
        #expect(bars.first?.height == 2)
        #expect(bars.map(\.minY) == [6, 9, 15])
        #expect(bars.map(\.widthFraction) == [0.125, 0.25, 1])
    }

    @Test func aLongConversationIsSqueezedToFit() {
        let blocks = (0..<10_000).map { Self.block($0, $0.isMultiple(of: 2) ? .user : .assistant) }
        let outline = ConversationOutline(blocks: blocks)
        let layout = Self.layout(outline, height: 700)

        let bars = layout.bars(for: outline, pixel: 0.5)

        #expect(layout.pitch < 3)
        #expect(bars.last.map { $0.minY + $0.height } ?? .infinity <= 694)
        #expect(bars.count <= Int(700 / 0.5))
        #expect(bars.first?.minY == 6)
    }

    @Test func aSharedPixelRowShowsYourMessage() {
        let outline = ConversationOutline(blocks: [Self.block(0, .toolRun, widths: [80], toolCalls: 1), Self.block(1, .user, widths: [8])])
        let layout = ConversationMapLayout(rowCount: outline.rowCount, height: 12.3, naturalPitch: 3, verticalInset: 6)

        let bars = layout.bars(for: outline, pixel: 1)

        #expect(bars.count == 1)
        #expect(bars.first?.ink == .user)
        #expect(bars.first?.widthFraction == 1)
    }

    @Test func aPointMapsToTheBlockUnderIt() throws {
        let outline = ConversationOutline(blocks: [
            Self.block(0, .user, widths: [10, 10]), Self.block(1, .assistant, widths: [10, 10, 10]),
        ])
        let layout = Self.layout(outline, height: 700)
        func block(atY y: CGFloat) -> Int? { outline.blockIndex(atRow: layout.row(atY: y)) }

        #expect(outline.rowStarts == [0, 3])
        #expect(block(atY: 0) == 0)
        #expect(block(atY: 6 + 3 * 1 + 1) == 0)
        #expect(block(atY: 6 + 3 * 2 + 1) == 0)
        #expect(block(atY: 6 + 3 * 3 + 1) == 1)
        #expect(block(atY: 1_000) == 1)
    }

    @Test func aToolRunOpensTheMessageBeforeOrAfterIt() {
        let outline = ConversationOutline(blocks: [
            Self.block(0, .toolRun, toolCalls: 2), Self.block(1, .user), Self.block(2, .toolRun, toolCalls: 1),
            Self.block(3, .image), Self.block(4, .assistant),
        ])

        #expect(outline.targetEntryID(forBlockAt: 0) == outline.blocks[1].entryID)
        #expect(outline.targetEntryID(forBlockAt: 2) == outline.blocks[1].entryID)
        #expect(outline.targetEntryID(forBlockAt: 3) == outline.blocks[3].entryID)
        #expect(outline.targetEntryID(forBlockAt: 4) == outline.blocks[4].entryID)
    }

    @Test(arguments: [false, true])
    func chipsNeverOverlapAndStayInside(atTheEnd: Bool) {
        let side: CGFloat = 14
        let height: CGFloat = 700
        let outline = ConversationOutline(blocks: (0..<300).map { Self.block($0, .assistant) })
        let records = atTheEnd ? Array(274..<300) : Array(0..<26)
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
        let bookmarks = zip(letters, records).map { Self.bookmark($0, at: $1) }.reversed()
        let layout = Self.layout(outline, height: height)

        let chips = layout.chips(for: Array(bookmarks), in: outline, side: side, height: height)

        #expect(chips.count == 26)
        #expect(chips.map(\.letter) == letters)
        for (upper, lower) in zip(chips, chips.dropFirst()) { #expect(lower.chipY - upper.chipY >= side + 1) }
        #expect(chips.allSatisfy { $0.chipY >= 0 && $0.chipY <= height - side })
    }

    @Test(arguments: [false, true])
    func chipsInAShortColumnOverlapButStayInside(atTheEnd: Bool) {
        let side: CGFloat = 21
        let height: CGFloat = 400
        let width: CGFloat = 105
        let outline = ConversationOutline(blocks: (0..<300).map { Self.block($0, .assistant) })
        let records = atTheEnd ? Array(274..<300) : Array(0..<26)
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
        let bookmarks = zip(letters, records).map { Self.bookmark($0, at: $1) }
        let layout = Self.layout(outline, height: height)

        let chips = layout.chips(for: bookmarks, in: outline, side: side, height: height)

        #expect(chips.map(\.letter) == letters)
        #expect(chips.allSatisfy { $0.chipY >= 0 && $0.chipY <= height - side })
        for (upper, lower) in zip(chips, chips.dropFirst()) { #expect(lower.chipY > upper.chipY) }
        for chip in chips {
            let found = layout.bookmark(
                at: CGPoint(x: width - 4, y: chip.chipY + 1), chips: chips, bookmarks: bookmarks, width: width, side: side)
            #expect(found?.letter == chip.letter)
        }
    }

    @Test func aBookmarkWithoutItsBlockHasNoChip() {
        let outline = ConversationOutline(blocks: [Self.block(0, .user), Self.block(1, .assistant)])
        let layout = Self.layout(outline, height: 700)

        #expect(layout.chips(for: [Self.bookmark("a", at: 9)], in: outline, side: 14, height: 700).isEmpty)
        #expect(layout.chips(for: [Self.bookmark("a", at: 1)], in: outline, side: 14, height: 700).count == 1)
    }

    @Test func aMovedPartKeepsItsChip() {
        let outline = ConversationOutline(blocks: [Self.block(0, .user), Self.block(5, .assistant, part: 1)])
        let layout = Self.layout(outline, height: 700)

        let chips = layout.chips(for: [Self.bookmark("c", at: 5, part: 0)], in: outline, side: 14, height: 700)

        #expect(chips.map(\.letter) == ["c"])
        #expect(chips.first?.rowY == layout.y(ofRow: outline.rowStarts[1]))
    }

    @Test func aClickOnAChipFindsItsBookmark() throws {
        let outline = ConversationOutline(blocks: [Self.block(0, .user), Self.block(1, .assistant)])
        let layout = Self.layout(outline, height: 700)
        let bookmarks = [Self.bookmark("a", at: 1)]
        let chips = layout.chips(for: bookmarks, in: outline, side: 14, height: 700)
        let chip = try #require(chips.first)

        #expect(
            layout.bookmark(at: CGPoint(x: 65, y: chip.chipY + 7), chips: chips, bookmarks: bookmarks, width: 70, side: 14) == bookmarks[0])
        #expect(layout.bookmark(at: CGPoint(x: 20, y: chip.chipY + 7), chips: chips, bookmarks: bookmarks, width: 70, side: 14) == nil)
        #expect(layout.bookmark(at: CGPoint(x: 65, y: chip.chipY + 40), chips: chips, bookmarks: bookmarks, width: 70, side: 14) == nil)
    }

    @Test func metricsScaleWithInterfaceSize() {
        #expect(InterfaceScale.points(70, at: 1.5) == 105)
        #expect(ConversationMapMetrics.columnWidth(at: 1.5) == 165)
        #expect(ConversationMapMetrics.minimumRowPitch(at: 1.5) == 1.5)
        #expect(ConversationMapMetrics.naturalRowPitch(at: 1.5) == 4.5)
        #expect(ConversationMapMetrics.chipSide(at: 1.5) == 21)
        #expect(ConversationMapMetrics.columnWidth(at: 1) == 110)
        #expect(ConversationMapMetrics.labelChipMaximumWidth(at: 1) == 89)
        #expect(ConversationMapMetrics.columnWidth == ConversationMapMetrics.columnWidth(at: InterfaceScale.factor))
    }
}
