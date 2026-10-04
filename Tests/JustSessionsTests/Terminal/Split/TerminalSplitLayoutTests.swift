import Foundation
import Testing
@testable import JustSessions

/// The panes sit inside the split area's insets, around the resize area; each pane keeps a workable minimum while the
/// window has room.
struct TerminalSplitLayoutTests {
    @Test func anEvenFractionPartsTheAvailableWidthEvenly() {
        // 1026 minus two 8-point insets and the 10-point resize area leaves 1000.
        let widths = TerminalSplitLayout.paneWidths(fraction: 0.5, totalWidth: 1026)
        #expect(widths.leading == 500)
        #expect(widths.trailing == 500)
    }

    @Test func paneWidthsTheInsetsAndTheResizeAreaAlwaysFillTheTotal() {
        for fraction in stride(from: 0.0, through: 1.0, by: 0.07) {
            let widths = TerminalSplitLayout.paneWidths(fraction: fraction, totalWidth: 987)
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
        let narrow = TerminalSplitLayout.paneWidths(fraction: 0.01, totalWidth: 1026)
        #expect(narrow.leading == TerminalSplitLayout.minimumPaneWidth)

        let wide = TerminalSplitLayout.paneWidths(fraction: 0.99, totalWidth: 1026)
        #expect(wide.trailing == TerminalSplitLayout.minimumPaneWidth)
    }

    @Test func aWindowTooNarrowForTwoMinimumPanesSplitsEvenly() {
        let total = TerminalSplitLayout.minimumPaneWidth * 2 - 50
        let widths = TerminalSplitLayout.paneWidths(fraction: 0.9, totalWidth: total)
        #expect(abs(widths.leading - widths.trailing) <= 1)
    }

    @Test func draggingTheResizeAreaMovesTheFractionByTheTravelledShare() {
        let total: CGFloat = 1026
        let availableWidth = TerminalSplitLayout.availableWidth(totalWidth: total)
        let dragged = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: availableWidth / 10, totalWidth: total)
        #expect(abs(dragged - 0.6) < 0.0001)
    }

    @Test func aDragEndingNearTheMiddleSnapsThePanesEven() {
        // 1026 leaves 1000 for the panes, so a left pane from 486 to 514 points wide snaps to 500.
        let fromTheLeft = TerminalSplitLayout.fraction(startingAt: 0.3, draggedBy: 190, totalWidth: 1026)
        #expect(fromTheLeft == TerminalSplitLayout.evenFraction)
        let fromTheRight = TerminalSplitLayout.fraction(startingAt: 0.7, draggedBy: -186, totalWidth: 1026)
        #expect(fromTheRight == TerminalSplitLayout.evenFraction)
        let nudgedFromEven = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: 14, totalWidth: 1026)
        #expect(nudgedFromEven == TerminalSplitLayout.evenFraction)
    }

    @Test func aDragEndingTheSnapDistanceOrMoreFromTheMiddleStaysWhereItIs() {
        let atTheSnapDistance = TerminalSplitLayout.fraction(startingAt: 0.3, draggedBy: 185, totalWidth: 1026)
        #expect(abs(atTheSnapDistance - 0.485) < 0.0001)
        let pastIt = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: 15, totalWidth: 1026)
        #expect(abs(pastIt - 0.515) < 0.0001)
    }

    @Test func aDragPastTheEdgeStopsAtTheMinimumPane() {
        let dragged = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: -5000, totalWidth: 1026)
        let widths = TerminalSplitLayout.paneWidths(fraction: dragged, totalWidth: 1026)
        #expect(widths.leading == TerminalSplitLayout.minimumPaneWidth)
    }
}
