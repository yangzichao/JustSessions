import CoreGraphics
import Foundation
import Testing
@testable import JustSessions

/// A tab dragged over the terminals takes the place under the pointer: with no split shown, the half of a new, even
/// split along either edge's third, or the whole area in the middle third; with a split shown, the pane it would
/// replace, parted by the resize area wherever it was dragged to.
struct TerminalSplitDropAreaTests {
    /// Terminals 1026 points wide and 600 high, below a 40-point tab bar and past a 200-point sidebar: each edge's
    /// third is 342 points wide, so the middle third runs from 542 to 884 in the window. With an even split, the resize
    /// area runs from 508 to 518 in them.
    private let terminalFrame = CGRect(x: 200, y: 40, width: 1026, height: 600)

    @Test func withNoSplitShownEitherEdgesThirdSplitsAndTheMiddleShowsTheTabOnItsOwn() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)

        #expect(area.place(at: CGPoint(x: 201, y: 41)) == .split(.left, .sideBySide))
        #expect(area.place(at: CGPoint(x: 541, y: 300)) == .split(.left, .sideBySide))
        #expect(area.place(at: CGPoint(x: 542, y: 300)) == .wholeArea)
        #expect(area.place(at: CGPoint(x: 713, y: 300)) == .wholeArea)
        #expect(area.place(at: CGPoint(x: 883, y: 300)) == .wholeArea)
        #expect(area.place(at: CGPoint(x: 884, y: 300)) == .split(.right, .sideBySide))
        #expect(area.place(at: CGPoint(x: 1225, y: 639)) == .split(.right, .sideBySide))
    }

    @Test func offTheTerminalsNoPlaceTakesTheTab() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)

        // Over the tab bar, the sidebar, and past the window's edges.
        #expect(area.place(at: CGPoint(x: 600, y: 20)) == nil)
        #expect(area.place(at: CGPoint(x: 100, y: 300)) == nil)
        #expect(area.place(at: CGPoint(x: 1300, y: 300)) == nil)
        #expect(area.place(at: CGPoint(x: 600, y: 700)) == nil)
    }

    @Test func withASplitShownTheResizeAreaPartsThePanesWhereverItWasDragged() {
        // 1000 points for the panes: the left one 300, so the resize area runs from 308 to 318.
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: .init(fraction: 0.3, orientation: .sideBySide))

        #expect(area.place(at: CGPoint(x: 200 + 312, y: 300)) == .split(.left, .sideBySide))
        #expect(area.place(at: CGPoint(x: 200 + 313, y: 300)) == .split(.right, .sideBySide))
        // In the middle, over the right pane, which the tab would take rather than showing on its own.
        #expect(area.place(at: CGPoint(x: 200 + 513, y: 300)) == .split(.right, .sideBySide))
    }

    @Test func theHighlightedPaneIsThePaneTheTabWouldTake() {
        let even = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)
        #expect(even.frame(of: .split(.left, .sideBySide)) == CGRect(x: 8, y: 8, width: 500, height: 584))
        #expect(even.frame(of: .split(.right, .sideBySide)) == CGRect(x: 518, y: 8, width: 500, height: 584))

        let shown = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: .init(fraction: 0.3, orientation: .sideBySide))
        #expect(shown.frame(of: .split(.left, .sideBySide)) == CGRect(x: 8, y: 8, width: 300, height: 584))
        #expect(shown.frame(of: .split(.right, .sideBySide)) == CGRect(x: 318, y: 8, width: 700, height: 584))
    }

    /// A tab shown on its own fills the terminals, inside the same insets as a split's panes.
    @Test func theWholeAreaIsHighlightedInsideTheSplitInsets() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)

        #expect(area.frame(of: .wholeArea) == CGRect(x: 8, y: 8, width: 1010, height: 584))
    }

    /// Its 600-point height has 200-point thirds along the top and bottom, which stack the tab above or below.
    @Test func withNoSplitShownTheTopAndBottomThirdsStackTheTab() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)

        #expect(area.place(at: CGPoint(x: 713, y: 41)) == .split(.left, .stacked))
        #expect(area.place(at: CGPoint(x: 713, y: 239)) == .split(.left, .stacked))
        #expect(area.place(at: CGPoint(x: 713, y: 240)) == .wholeArea)
        #expect(area.place(at: CGPoint(x: 713, y: 439)) == .wholeArea)
        #expect(area.place(at: CGPoint(x: 713, y: 440)) == .split(.right, .stacked))
        #expect(area.place(at: CGPoint(x: 713, y: 639)) == .split(.right, .stacked))
    }

    /// Where a side third and a top or bottom third meet, the edge the pointer is nearer for the area's size wins.
    @Test func inACornerTheNearerEdgeForTheAreasSizeTakesTheTab() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)

        // 100 points from the left is under a tenth of the width; 100 from the top is a sixth of the height.
        #expect(area.place(at: CGPoint(x: 300, y: 140)) == .split(.left, .sideBySide))
        // 300 points from the left is past a quarter of the width; 50 from the bottom is a twelfth of the height.
        #expect(area.place(at: CGPoint(x: 500, y: 590)) == .split(.right, .stacked))
    }

    @Test func withAStackedSplitShownTheResizeAreaPartsTheTopAndBottomPanes() {
        // 574 points for the panes: the top one 287, so the resize area runs from 295 to 305 down the terminals.
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: .init(fraction: 0.5, orientation: .stacked))

        #expect(area.place(at: CGPoint(x: 210, y: 40 + 299)) == .split(.left, .stacked))
        #expect(area.place(at: CGPoint(x: 210, y: 40 + 300)) == .split(.right, .stacked))
        // Along the left edge, over the bottom pane, which the tab would take rather than splitting side by side.
        #expect(area.place(at: CGPoint(x: 201, y: 600)) == .split(.right, .stacked))
        #expect(area.frame(of: .split(.left, .stacked)) == CGRect(x: 8, y: 8, width: 1010, height: 287))
        #expect(area.frame(of: .split(.right, .stacked)) == CGRect(x: 8, y: 305, width: 1010, height: 287))
    }

    /// A split's own pane, dragged by its toolbar, finds the edges as with no split shown.
    @Test func ignoringTheShownSplitFindsTheEdges() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: .init(fraction: 0.3, orientation: .sideBySide))
        let windowFrame = CGRect(x: 0, y: 0, width: 1226, height: 640)

        #expect(area.place(atScreenPoint: CGPoint(x: 713, y: 640 - 600), windowFrame: windowFrame, ignoringShownSplit: true)
            == .split(.right, .stacked))
        #expect(area.place(atScreenPoint: CGPoint(x: 713, y: 640 - 340), windowFrame: windowFrame, ignoringShownSplit: true)
            == .wholeArea)
        // The shown split's fraction is kept for its own layout, and a new layout starts even.
        #expect(area.frame(of: .split(.left, .sideBySide)) == CGRect(x: 8, y: 8, width: 300, height: 584))
        #expect(area.frame(of: .split(.left, .stacked)) == CGRect(x: 8, y: 8, width: 1010, height: 287))
    }

    /// The pointer comes in screen coordinates, measured from the bottom, and the area in the window, from its top.
    @Test func aPointerOnScreenIsMeasuredFromTheWindowsTopLeadingCorner() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)
        // The window's top edge is at 1000 on screen.
        let windowFrame = CGRect(x: 100, y: 300, width: 1226, height: 700)

        #expect(area.place(atScreenPoint: CGPoint(x: 100 + 300, y: 1000 - 340), windowFrame: windowFrame) == .split(.left, .sideBySide))
        #expect(area.place(atScreenPoint: CGPoint(x: 100 + 700, y: 1000 - 340), windowFrame: windowFrame) == .wholeArea)
        #expect(area.place(atScreenPoint: CGPoint(x: 100 + 900, y: 1000 - 340), windowFrame: windowFrame) == .split(.right, .sideBySide))
        // Over the tab bar.
        #expect(area.place(atScreenPoint: CGPoint(x: 100 + 900, y: 1000 - 20), windowFrame: windowFrame) == nil)
    }
}
