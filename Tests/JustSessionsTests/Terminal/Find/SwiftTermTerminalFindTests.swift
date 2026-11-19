import AppKit
import Testing

@testable import JustSessions

/// Find in a SwiftTerm tab; see `GhosttyTerminalFindTests` for Ghostty's.
@MainActor
struct SwiftTermTerminalFindTests {
    private func makeTerminalWithThreeMatches() -> SelectableTerminalView {
        let terminalView = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        terminalView.feed(text: TerminalFindFixtureOutput.linesWithThreeNeedles.joined(separator: "\r\n"))
        return terminalView
    }

    /// Whether a buffer row is in view. Row 199 is line 200, as long as no line has left the buffer.
    private func isShown(row: Int, in terminalView: SelectableTerminalView) -> Bool {
        let terminal = terminalView.getTerminal()
        let topRow = terminal.getTopVisibleRow()
        return (topRow..<(topRow + terminal.rows)).contains(row)
    }

    @Test func aSearchSelectsTheNewestMatchAndScrollsToIt() {
        let terminalView = makeTerminalWithThreeMatches()
        #expect(!isShown(row: 199, in: terminalView))

        let count = terminalView.findText("NEEDLE")

        #expect(count == TerminalFindMatchCount(total: 3, selectedNumber: 1, exceedsCountLimit: false))
        #expect(terminalView.getSelection() == "needle")
        #expect(isShown(row: 199, in: terminalView))
    }

    @Test func movesGoTowardOlderOrNewerOutputAndWrap() {
        let terminalView = makeTerminalWithThreeMatches()
        _ = terminalView.findText("needle")

        #expect(terminalView.findTextAgain("needle", direction: .towardOlder)?.selectedNumber == 2)
        #expect(isShown(row: 149, in: terminalView))
        #expect(terminalView.findTextAgain("needle", direction: .towardOlder)?.selectedNumber == 3)
        #expect(isShown(row: 9, in: terminalView))
        #expect(terminalView.findTextAgain("needle", direction: .towardOlder)?.selectedNumber == 1)
        #expect(terminalView.findTextAgain("needle", direction: .towardNewer)?.selectedNumber == 3)
        #expect(terminalView.findTextAgain("needle", direction: .towardNewer)?.selectedNumber == 2)
        #expect(isShown(row: 149, in: terminalView))
    }

    @Test func aQueryWithNoMatchCountsNone() {
        let terminalView = makeTerminalWithThreeMatches()

        #expect(terminalView.findText("haystack") == TerminalFindMatchCount.none)
        #expect(terminalView.getSelection() == nil)
    }

    @Test func endingTheSearchTakesTheSelectionAway() {
        let terminalView = makeTerminalWithThreeMatches()
        _ = terminalView.findText("needle")

        terminalView.endTextFind()

        #expect(terminalView.getSelection() == nil)
    }

    /// SwiftTerm keeps 500 lines by default; a tab keeps `scrollbackLineCount`.
    @Test func findReachesTenThousandLinesBack() {
        let terminalView = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let lines = (1...10_500).map { String(format: "row-%05d", $0) }
        terminalView.feed(text: lines.joined(separator: "\r\n"))

        #expect(terminalView.findText("row-00600")?.total == 1)
        #expect(terminalView.findText("row-00001")?.total == 0)
    }
}

/// 300 numbered lines, three of them with "needle": the oldest on line 10, then 150, and the newest on 200.
enum TerminalFindFixtureOutput {
    static let linesWithThreeNeedles: [String] = {
        var lines = (1...300).map { String(format: "line-%04d", $0) }
        lines[9] = "line-0010 needle-old"
        lines[149] = "line-0150 needle-mid"
        lines[199] = "line-0200 needle-new"
        return lines
    }()
}
