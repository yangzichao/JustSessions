import CoreGraphics
import Foundation
import Testing

@testable import JustSessions

struct TerminalSplitDropAreaTests {
    private static let sidebarWidth: CGFloat = 200
    private static let tabBarHeight: CGFloat = 40
    private let terminalFrame = CGRect(x: sidebarWidth, y: tabBarHeight, width: 1026, height: 600)

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

        #expect(area.place(at: CGPoint(x: 600, y: 20)) == nil)
        #expect(area.place(at: CGPoint(x: 100, y: 300)) == nil)
        #expect(area.place(at: CGPoint(x: 1300, y: 300)) == nil)
        #expect(area.place(at: CGPoint(x: 600, y: 700)) == nil)
    }

    @Test func withASplitShownTheResizeAreaPartsThePanesWhereverItWasDragged() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: .init(fraction: 0.3, orientation: .sideBySide))

        #expect(area.place(at: CGPoint(x: Self.sidebarWidth + 312, y: 300)) == .split(.left, .sideBySide))
        #expect(area.place(at: CGPoint(x: Self.sidebarWidth + 313, y: 300)) == .split(.right, .sideBySide))
        #expect(area.place(at: CGPoint(x: Self.sidebarWidth + 513, y: 300)) == .split(.right, .sideBySide))
    }

    @Test func theHighlightedPaneIsThePaneTheTabWouldTake() {
        let even = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)
        #expect(even.frame(of: .split(.left, .sideBySide)) == CGRect(x: 8, y: 8, width: 500, height: 584))
        #expect(even.frame(of: .split(.right, .sideBySide)) == CGRect(x: 518, y: 8, width: 500, height: 584))

        let shown = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: .init(fraction: 0.3, orientation: .sideBySide))
        #expect(shown.frame(of: .split(.left, .sideBySide)) == CGRect(x: 8, y: 8, width: 300, height: 584))
        #expect(shown.frame(of: .split(.right, .sideBySide)) == CGRect(x: 318, y: 8, width: 700, height: 584))
    }

    @Test func theWholeAreaIsHighlightedInsideTheSplitInsets() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)

        #expect(area.frame(of: .wholeArea) == CGRect(x: 8, y: 8, width: 1010, height: 584))
    }

    @Test func withNoSplitShownTheTopAndBottomThirdsStackTheTab() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)

        #expect(area.place(at: CGPoint(x: 713, y: 41)) == .split(.left, .stacked))
        #expect(area.place(at: CGPoint(x: 713, y: 239)) == .split(.left, .stacked))
        #expect(area.place(at: CGPoint(x: 713, y: 240)) == .wholeArea)
        #expect(area.place(at: CGPoint(x: 713, y: 439)) == .wholeArea)
        #expect(area.place(at: CGPoint(x: 713, y: 440)) == .split(.right, .stacked))
        #expect(area.place(at: CGPoint(x: 713, y: 639)) == .split(.right, .stacked))
    }

    @Test func inACornerTheNearerEdgeForTheAreasSizeTakesTheTab() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)

        #expect(area.place(at: CGPoint(x: 300, y: 140)) == .split(.left, .sideBySide))
        #expect(area.place(at: CGPoint(x: 500, y: 590)) == .split(.right, .stacked))
    }

    @Test func withAStackedSplitShownTheResizeAreaPartsTheTopAndBottomPanes() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: .init(fraction: 0.5, orientation: .stacked))

        #expect(area.place(at: CGPoint(x: 210, y: Self.tabBarHeight + 299)) == .split(.left, .stacked))
        #expect(area.place(at: CGPoint(x: 210, y: Self.tabBarHeight + 300)) == .split(.right, .stacked))
        #expect(area.place(at: CGPoint(x: 201, y: 600)) == .split(.right, .stacked))
        #expect(area.frame(of: .split(.left, .stacked)) == CGRect(x: 8, y: 8, width: 1010, height: 287))
        #expect(area.frame(of: .split(.right, .stacked)) == CGRect(x: 8, y: 305, width: 1010, height: 287))
    }

    @Test func ignoringTheShownSplitFindsTheEdges() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: .init(fraction: 0.3, orientation: .sideBySide))
        let windowFrame = CGRect(x: 0, y: 0, width: 1226, height: 640)

        #expect(
            area.place(atScreenPoint: CGPoint(x: 713, y: 640 - 600), windowFrame: windowFrame, ignoringShownSplit: true)
                == .split(.right, .stacked))
        #expect(
            area.place(atScreenPoint: CGPoint(x: 713, y: 640 - 340), windowFrame: windowFrame, ignoringShownSplit: true)
                == .wholeArea)
        #expect(area.frame(of: .split(.left, .sideBySide)) == CGRect(x: 8, y: 8, width: 300, height: 584))
        #expect(area.frame(of: .split(.left, .stacked)) == CGRect(x: 8, y: 8, width: 1010, height: 287))
    }

    @Test func aPointerOnScreenIsMeasuredFromTheWindowsTopLeadingCorner() {
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: nil)
        let windowFrame = CGRect(x: 100, y: 300, width: 1226, height: 700)

        #expect(area.place(atScreenPoint: CGPoint(x: 100 + 300, y: 1000 - 340), windowFrame: windowFrame) == .split(.left, .sideBySide))
        #expect(area.place(atScreenPoint: CGPoint(x: 100 + 700, y: 1000 - 340), windowFrame: windowFrame) == .wholeArea)
        #expect(area.place(atScreenPoint: CGPoint(x: 100 + 900, y: 1000 - 340), windowFrame: windowFrame) == .split(.right, .sideBySide))
        #expect(area.place(atScreenPoint: CGPoint(x: 100 + 900, y: 1000 - 20), windowFrame: windowFrame) == nil)
    }
}
