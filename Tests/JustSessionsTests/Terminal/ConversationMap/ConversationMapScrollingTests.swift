import CoreGraphics
import Testing

@testable import JustSessions

/// A conversation too long to show at a third of full size scrolls (TAB-10): it starts at, and follows, its newest
/// rows; scrolled away it keeps its rows in view; only rows in view are drawn; and bookmarks scrolled away wait at the
/// column's edges. Labelled bookmarks' chips show their label.
@MainActor
struct ConversationMapScrollingTests {
    private static let height: CGFloat = 700

    private static func outline(blocks count: Int) -> ConversationOutline {
        ConversationOutline(
            blocks: (0..<count).map { record in
                ConversationOutline.Block(
                    entryID: TranscriptPageIdentity.entryID(record: record, part: 0), lastRecord: record,
                    kind: record.isMultiple(of: 2) ? .user : .assistant, timestamp: nil,
                    snippet: "Block \(record)", lineWidths: [40, 30], toolCallCount: 0)
            })
    }

    private static func layout(_ outline: ConversationOutline, offsetFromTop: CGFloat? = nil) -> ConversationMapLayout {
        ConversationMapLayout(
            rowCount: outline.rowCount, height: height, naturalPitch: 3, verticalInset: 6, minimumPitch: 1,
            offsetFromTop: offsetFromTop)
    }

    /// On a reply: the odd records are the CLI's.
    private static func bookmark(_ letter: String, at record: Int, label: String? = nil) -> MessageBookmark {
        var bookmark = MessageBookmark(
            letter: letter, entryID: TranscriptPageIdentity.entryID(record: record, part: 0),
            kind: .assistant, snippet: "")
        bookmark.label = label
        return bookmark
    }

    @Test func aConversationThatFitsAtAThirdOfFullSizeIsSqueezedAndNeverScrolls() {
        // 229 blocks of two lines, each after a blank row: 686 rows, a little over a point each in the 688 there are.
        let fits = Self.layout(Self.outline(blocks: 229), offsetFromTop: 200)
        // One more needs 689 rows: at the minimum of a point each, the last point scrolls.
        let overflows = Self.layout(Self.outline(blocks: 230))

        #expect(fits.pitch > 1 && fits.pitch < 3)
        #expect(!fits.isScrollable)
        #expect(fits.top == 6)
        #expect(fits.scrollThumb(minimumLength: 16) == nil)
        #expect(overflows.pitch == 1)
        #expect(overflows.maximumScrollOffset == 1)
    }

    @Test func aLongerOneStartsAtItsNewestRowsAndKeepsThemAsItGrows() throws {
        let outline = Self.outline(blocks: 3_000)
        let layout = Self.layout(outline)

        let bars = layout.bars(for: outline, pixel: 0.5)

        #expect(layout.pitch == 1)
        #expect(layout.isScrollable)
        #expect(layout.scrollOffset == layout.maximumScrollOffset)
        let last = try #require(bars.last)
        #expect(last.minY + last.height <= Self.height - 6 && last.minY + last.height > Self.height - 8)
        let grown = Self.layout(Self.outline(blocks: 3_010))
        #expect(grown.y(ofRow: grown.rowCount - 1) == layout.y(ofRow: layout.rowCount - 1))
    }

    @Test func scrolledAwayItKeepsItsRowsInViewAndScrollingBackFollowsTheNewestAgain() throws {
        let outline = Self.outline(blocks: 3_000)
        let newest = Self.layout(outline)
        let offset = try #require(newest.offsetFromTop(afterScrollingBy: -500))
        let scrolled = Self.layout(outline, offsetFromTop: offset)
        let grown = Self.layout(Self.outline(blocks: 3_010), offsetFromTop: offset)

        #expect(offset == newest.maximumScrollOffset - 500)
        #expect(scrolled.y(ofRow: 1_000) == newest.y(ofRow: 1_000) + 500)
        #expect(grown.y(ofRow: 1_000) == scrolled.y(ofRow: 1_000))
        #expect(scrolled.offsetFromTop(afterScrollingBy: 499) != nil)
        #expect(scrolled.offsetFromTop(afterScrollingBy: 500) == nil)
        #expect(Self.layout(outline, offsetFromTop: 0).offsetFromTop(afterScrollingBy: -50) == 0)
    }

    @Test func onlyTheRowsInViewAreDrawn() {
        let outline = Self.outline(blocks: 3_000)
        for offset in [0, 3_000, nil] as [CGFloat?] {
            let layout = Self.layout(outline, offsetFromTop: offset)

            let bars = layout.bars(for: outline, pixel: 0.5)

            #expect(!bars.isEmpty)
            #expect(bars.count <= Int(Self.height) + 2)
            #expect(bars.allSatisfy { $0.minY >= -1 && $0.minY <= Self.height })
        }
    }

    @Test func theLeadingBarShowsWhereTheRowsInViewAre() throws {
        let outline = Self.outline(blocks: 3_000)

        let top = try #require(Self.layout(outline, offsetFromTop: 0).scrollThumb(minimumLength: 16))
        let newest = try #require(Self.layout(outline).scrollThumb(minimumLength: 16))

        #expect(top.minY == 0)
        #expect(top.height >= 16 && top.height < Self.height / 4)
        #expect(abs(newest.minY + newest.height - Self.height) < 0.001)
    }

    @Test func bookmarksScrolledAwayWaitAtTheEdgesAndStillTakeClicks() throws {
        let outline = Self.outline(blocks: 3_000)
        let layout = Self.layout(outline, offsetFromTop: 4_000)
        let bookmarks = [Self.bookmark("a", at: 3), Self.bookmark("b", at: 1_401), Self.bookmark("c", at: 2_991)]

        let chips = layout.chips(for: bookmarks, in: outline, side: 14, height: Self.height)

        #expect(chips.map(\.letter) == ["a", "b", "c"])
        #expect(chips[0].chipY == 0 && chips[0].rowY < 0)
        #expect(chips[1].rowY > 0 && chips[1].rowY < Self.height)
        #expect(chips[2].chipY == Self.height - 14 && chips[2].rowY > Self.height)
        let found = layout.bookmark(at: CGPoint(x: 100, y: 3), chips: chips, bookmarks: bookmarks, width: 110, side: 14)
        #expect(found?.letter == "a")
    }

    @Test func aLabelledChipIsAsWideAsItsTitleAndTakesClicksAcrossIt() throws {
        let outline = Self.outline(blocks: 20)
        let layout = Self.layout(outline)
        let bookmarks = [Self.bookmark("a", at: 5, label: "Fix login"), Self.bookmark("b", at: 11)]
        let titles = ["a": ConversationMapLayout.ChipTitle(text: "Fix login", width: 60)]

        let chips = layout.chips(for: bookmarks, in: outline, side: 14, height: Self.height, titles: titles)

        let labelled = try #require(chips.first { $0.letter == "a" })
        let lettered = try #require(chips.first { $0.letter == "b" })
        #expect(labelled.title == titles["a"])
        #expect(lettered.title == .init(text: "b", width: 14))
        #expect(ConversationMapLayout.chipMinX(of: labelled, width: 110) == 47)
        let point = { (x: CGFloat) in CGPoint(x: x, y: labelled.chipY + 7) }
        #expect(layout.bookmark(at: point(48), chips: chips, bookmarks: bookmarks, width: 110, side: 14)?.letter == "a")
        #expect(layout.bookmark(at: point(46), chips: chips, bookmarks: bookmarks, width: 110, side: 14) == nil)
    }
}

/// A label shows whole while it fits, else cut with …, never wider than the most a label's chip may be.
@MainActor
struct ConversationMapChipTitlesTests {
    private static func bookmark(_ letter: String, label: String?) -> MessageBookmark {
        var bookmark = MessageBookmark(
            letter: letter, entryID: TranscriptPageIdentity.entryID(record: 0, part: 0),
            kind: .assistant, snippet: "")
        bookmark.label = label
        return bookmark
    }

    @Test func shortLabelsShowWholeLongOnesAreCutAndOthersKeepTheirLetter() throws {
        let maximum = ConversationMapMetrics.labelChipMaximumWidth(at: 1)
        let titles = ConversationMapChipTitles.titles(
            for: [
                Self.bookmark("a", label: "Fix login"),
                Self.bookmark("b", label: "The migration that dropped the sessions table on staging"),
                Self.bookmark("c", label: nil),
                Self.bookmark("d", label: "  \n "),
                Self.bookmark("e", label: "Two\nlines"),
            ], side: 14, factor: 1)

        let short = try #require(titles["a"])
        let long = try #require(titles["b"])
        #expect(short.text == "Fix login")
        #expect(short.width > 14 && short.width < maximum)
        #expect(long.text.hasSuffix("…"))
        #expect(long.text.count > 8)
        #expect(long.width <= maximum)
        #expect(titles["c"] == nil && titles["d"] == nil)
        #expect(titles["e"]?.text == "Two lines")
    }

    @Test func aOneCharacterLabelIsAtLeastASquare() {
        let title = ConversationMapChipTitles.title(for: "i", side: 14, factor: 1)

        #expect(title.width == 14)
    }
}
