import Foundation
import Testing
@testable import JustSessions

/// The panes sit inside the split area's insets, around the resize area; each pane keeps a workable minimum while the
/// window has room.
struct TerminalSplitLayoutTests {
    @Test func anEvenFractionPartsTheAvailableWidthEvenly() {
        // 1026 minus two 8-point insets and the 10-point resize area leaves 1000.
        let widths = TerminalSplitLayout.paneLengths(fraction: 0.5, totalLength: 1026)
        #expect(widths.leading == 500)
        #expect(widths.trailing == 500)
    }

    @Test func paneWidthsTheInsetsAndTheResizeAreaAlwaysFillTheTotal() {
        for fraction in stride(from: 0.0, through: 1.0, by: 0.07) {
            let widths = TerminalSplitLayout.paneLengths(fraction: fraction, totalLength: 987)
            let total = widths.leading + widths.trailing + TerminalSplitLayout.resizeAreaWidth + 2 * TerminalSplitLayout.contentInset
            #expect(total == 987)
        }
    }

    @Test func thePanesSitInsideTheInsetsWithTheResizeAreaBetweenThem() {
        let frames = TerminalSplitLayout.frames(fraction: 0.5, size: CGSize(width: 1026, height: 600))
        #expect(frames.left == CGRect(x: 8, y: 8, width: 500, height: 584))
        #expect(frames.resizeArea == CGRect(x: 508, y: 8, width: 10, height: 584))
        #expect(frames.right == CGRect(x: 518, y: 8, width: 500, height: 584))
        #expect(frames.right.maxX + TerminalSplitLayout.contentInset == 1026)
    }

    @Test func neitherPaneGetsNarrowerThanTheMinimum() {
        let narrow = TerminalSplitLayout.paneLengths(fraction: 0.01, totalLength: 1026)
        #expect(narrow.leading == TerminalSplitLayout.minimumPaneWidth)

        let wide = TerminalSplitLayout.paneLengths(fraction: 0.99, totalLength: 1026)
        #expect(wide.trailing == TerminalSplitLayout.minimumPaneWidth)
    }

    @Test func aWindowTooNarrowForTwoMinimumPanesSplitsEvenly() {
        let total = TerminalSplitLayout.minimumPaneWidth * 2 - 50
        let widths = TerminalSplitLayout.paneLengths(fraction: 0.9, totalLength: total)
        #expect(abs(widths.leading - widths.trailing) <= 1)
    }

    @Test func draggingTheResizeAreaMovesTheFractionByTheTravelledShare() {
        let total: CGFloat = 1026
        let availableLength = TerminalSplitLayout.availableLength(totalLength: total)
        let dragged = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: availableLength / 10, totalLength: total)
        #expect(abs(dragged - 0.6) < 0.0001)
    }

    @Test func aDragEndingNearTheMiddleSnapsThePanesEven() {
        // 1026 leaves 1000 for the panes, so a left pane from 486 to 514 points wide snaps to 500.
        let fromTheLeft = TerminalSplitLayout.fraction(startingAt: 0.3, draggedBy: 190, totalLength: 1026)
        #expect(fromTheLeft == TerminalSplitLayout.evenFraction)
        let fromTheRight = TerminalSplitLayout.fraction(startingAt: 0.7, draggedBy: -186, totalLength: 1026)
        #expect(fromTheRight == TerminalSplitLayout.evenFraction)
        let nudgedFromEven = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: 14, totalLength: 1026)
        #expect(nudgedFromEven == TerminalSplitLayout.evenFraction)
    }

    @Test func aDragEndingTheSnapDistanceOrMoreFromTheMiddleStaysWhereItIs() {
        let atTheSnapDistance = TerminalSplitLayout.fraction(startingAt: 0.3, draggedBy: 185, totalLength: 1026)
        #expect(abs(atTheSnapDistance - 0.485) < 0.0001)
        let pastIt = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: 15, totalLength: 1026)
        #expect(abs(pastIt - 0.515) < 0.0001)
    }

    @Test func stackedPanesRunTheWidthWithTheResizeAreaAcrossBetweenThem() {
        // 600 minus two 8-point insets and the 10-point resize area leaves 574.
        let frames = TerminalSplitLayout.frames(fraction: 0.5, size: CGSize(width: 1026, height: 600), orientation: .stacked)
        #expect(frames.left == CGRect(x: 8, y: 8, width: 1010, height: 287))
        #expect(frames.resizeArea == CGRect(x: 8, y: 295, width: 1010, height: 10))
        #expect(frames.right == CGRect(x: 8, y: 305, width: 1010, height: 287))
        #expect(frames.right.maxY + TerminalSplitLayout.contentInset == 600)
    }

    @Test func neitherStackedPaneGetsShorterThanTheMinimum() {
        let short = TerminalSplitLayout.paneLengths(fraction: 0.01, totalLength: 600, orientation: .stacked)
        #expect(short.leading == TerminalSplitLayout.minimumPaneHeight)

        let tall = TerminalSplitLayout.paneLengths(fraction: 0.99, totalLength: 600, orientation: .stacked)
        #expect(tall.trailing == TerminalSplitLayout.minimumPaneHeight)
    }

    @Test func draggingAStackedResizeAreaSnapsAndStopsAsASideBySideOneDoes() {
        // 600 leaves 574 for the panes, so a top pane from 273 to 301 points tall snaps to 287.
        let nearTheMiddle = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: 10, totalLength: 600, orientation: .stacked)
        #expect(nearTheMiddle == TerminalSplitLayout.evenFraction)

        let pastTheEdge = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: -5000, totalLength: 600, orientation: .stacked)
        let lengths = TerminalSplitLayout.paneLengths(fraction: pastTheEdge, totalLength: 600, orientation: .stacked)
        #expect(lengths.leading == TerminalSplitLayout.minimumPaneHeight)
    }

    @Test func aDragPastTheEdgeStopsAtTheMinimumPane() {
        let dragged = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: -5000, totalLength: 1026)
        let widths = TerminalSplitLayout.paneLengths(fraction: dragged, totalLength: 1026)
        #expect(widths.leading == TerminalSplitLayout.minimumPaneWidth)
    }
}
