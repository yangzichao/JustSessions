import Foundation
import Testing
@testable import JustSessions

/// The divider parts the split's width beside it; each pane keeps a workable minimum while the window has room.
struct TerminalSplitLayoutTests {
    @Test func anEvenFractionPartsTheAvailableWidthEvenly() {
        let widths = TerminalSplitLayout.paneWidths(fraction: 0.5, totalWidth: 1001)
        #expect(widths.leading == 500)
        #expect(widths.trailing == 500)
    }

    @Test func paneWidthsAndTheDividerAlwaysFillTheTotal() {
        for fraction in stride(from: 0.0, through: 1.0, by: 0.07) {
            let widths = TerminalSplitLayout.paneWidths(fraction: fraction, totalWidth: 987)
            #expect(widths.leading + widths.trailing + TerminalSplitLayout.dividerWidth == 987)
        }
    }

    @Test func neitherPaneGetsNarrowerThanTheMinimum() {
        let narrow = TerminalSplitLayout.paneWidths(fraction: 0.01, totalWidth: 1001)
        #expect(narrow.leading == TerminalSplitLayout.minimumPaneWidth)

        let wide = TerminalSplitLayout.paneWidths(fraction: 0.99, totalWidth: 1001)
        #expect(wide.trailing == TerminalSplitLayout.minimumPaneWidth)
    }

    @Test func aWindowTooNarrowForTwoMinimumPanesSplitsEvenly() {
        let total = TerminalSplitLayout.minimumPaneWidth * 2 - 50
        let widths = TerminalSplitLayout.paneWidths(fraction: 0.9, totalWidth: total)
        #expect(abs(widths.leading - widths.trailing) <= 1)
    }

    @Test func draggingTheDividerMovesTheFractionByTheTravelledShare() {
        let total: CGFloat = 1001
        let availableWidth = TerminalSplitLayout.availableWidth(totalWidth: total)
        let dragged = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: availableWidth / 10, totalWidth: total)
        #expect(abs(dragged - 0.6) < 0.0001)
    }

    @Test func aDragPastTheEdgeStopsAtTheMinimumPane() {
        let dragged = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: -5000, totalWidth: 1001)
        let widths = TerminalSplitLayout.paneWidths(fraction: dragged, totalWidth: 1001)
        #expect(widths.leading == TerminalSplitLayout.minimumPaneWidth)
    }
}
