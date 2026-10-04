import Foundation
import Testing
@testable import JustSessions

/// The divider parts the split's width beside it; each pane keeps a workable minimum while the window has room. It
/// stays put while a tab keeps its side of a changed pair, mirrors on a swap, and starts even otherwise.
struct TerminalSplitLayoutTests {
    @Test func anEvenFractionPartsTheAvailableWidthEvenly() {
        let widths = TerminalSplitLayout.paneWidths(fraction: 0.5, totalWidth: 1008)
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
        let narrow = TerminalSplitLayout.paneWidths(fraction: 0.01, totalWidth: 1008)
        #expect(narrow.leading == TerminalSplitLayout.minimumPaneWidth)

        let wide = TerminalSplitLayout.paneWidths(fraction: 0.99, totalWidth: 1008)
        #expect(wide.trailing == TerminalSplitLayout.minimumPaneWidth)
    }

    @Test func aWindowTooNarrowForTwoMinimumPanesSplitsEvenly() {
        let total = TerminalSplitLayout.minimumPaneWidth * 2 - 50
        let widths = TerminalSplitLayout.paneWidths(fraction: 0.9, totalWidth: total)
        #expect(abs(widths.leading - widths.trailing) <= 1)
    }

    @Test func draggingTheDividerMovesTheFractionByTheTravelledShare() {
        let total: CGFloat = 1008
        let availableWidth = TerminalSplitLayout.availableWidth(totalWidth: total)
        let dragged = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: availableWidth / 10, totalWidth: total)
        #expect(abs(dragged - 0.6) < 0.0001)
    }

    @Test func aDragPastTheEdgeStopsAtTheMinimumPane() {
        let dragged = TerminalSplitLayout.fraction(startingAt: 0.5, draggedBy: -5000, totalWidth: 1008)
        let widths = TerminalSplitLayout.paneWidths(fraction: dragged, totalWidth: 1008)
        #expect(widths.leading == TerminalSplitLayout.minimumPaneWidth)
    }

    @Test func swappingThePairMirrorsTheDivider() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        #expect(abs(TerminalSplitLayout.fraction(0.3, afterPairChangeFrom: pair, to: pair.swapped) - 0.7) < 0.0001)
    }

    @Test func aTabKeepingTheLeftPaneKeepsTheDivider() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        let newPair = TerminalSplitPair(leadingID: first, trailingID: third)
        #expect(TerminalSplitLayout.fraction(0.3, afterPairChangeFrom: pair, to: newPair) == 0.3)
    }

    @Test func aTabKeepingTheRightPaneKeepsTheDivider() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        let newPair = TerminalSplitPair(leadingID: third, trailingID: second)
        #expect(TerminalSplitLayout.fraction(0.3, afterPairChangeFrom: pair, to: newPair) == 0.3)
    }

    @Test func aTabChangingSidesStartsEven() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        let newPair = TerminalSplitPair(leadingID: third, trailingID: first)
        #expect(TerminalSplitLayout.fraction(0.3, afterPairChangeFrom: pair, to: newPair) == TerminalSplitLayout.evenFraction)
    }

    @Test func aPairOfOtherTabsStartsEven() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        let newPair = TerminalSplitPair(leadingID: third, trailingID: fourth)
        #expect(TerminalSplitLayout.fraction(0.3, afterPairChangeFrom: pair, to: newPair) == TerminalSplitLayout.evenFraction)
    }

    @Test func aFirstSplitStartsEven() {
        let newPair = TerminalSplitPair(leadingID: first, trailingID: second)
        #expect(TerminalSplitLayout.fraction(0.3, afterPairChangeFrom: nil, to: newPair) == TerminalSplitLayout.evenFraction)
    }

    private let first = UUID()
    private let second = UUID()
    private let third = UUID()
    private let fourth = UUID()
}
