import AppKit
import Testing

@testable import JustSessions

/// A ⌘-click or right-click on a link a CLI broke over rows gets all of it, whichever engine draws the terminal:
/// SwiftTerm joins such rows itself, and a Ghostty tab joins them with `HardWrappedLink`. The CLI's screen is shown as
/// tmux draws Claude Code's reply: the URL runs to the last column, the row ends, and the rest follows on the next row
/// after two spaces.
@MainActor
@Suite(.serialized)
struct TerminalHardWrappedLinkClickTests {
    private static let mouseReportingOn = "\u{1B}[?1000h\u{1B}[?1006h"
    private static let firstRowLead = "See "
    nonisolated private static let cases: [(TerminalEngine, Int)] = TerminalEngine.allCases.flatMap { [($0, 0), ($0, 1)] }

    @Test(arguments: cases)
    func commandClickingEitherRowOfABrokenURLOpensAllOfIt(_ engine: TerminalEngine, row: Int) async throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        let grid = try await terminal.grid()
        terminal.show(Self.mouseReportingOn)
        let url = Self.longURL(for: grid)
        terminal.show(Self.brokenRows(showing: url, in: grid))

        try TerminalClick.click(terminal.view, column: 6, row: row, in: grid, modifierFlags: .command)

        #expect(terminal.openedLinks == [url])
    }

    /// Claude Code links the URLs in its replies with OSC 8, every row's part to the whole URL, and a link's target
    /// may differ from its text.
    @Test(arguments: cases)
    func aHyperlinksTargetStillWins(_ engine: TerminalEngine, row: Int) async throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        let grid = try await terminal.grid()
        terminal.show(Self.mouseReportingOn)
        let target = "https://example.com/target"
        let hyperlinkStart = "\u{1B}]8;;\(target)\u{1B}\\"
        let hyperlinkEnd = "\u{1B}]8;;\u{1B}\\"
        let url = Self.longURL(for: grid)
        let firstRowPart = url.prefix(grid.columns - Self.firstRowLead.count)
        terminal.show(
            Self.firstRowLead + hyperlinkStart + firstRowPart + hyperlinkEnd + "\r\n"
                + "  " + hyperlinkStart + url.dropFirst(firstRowPart.count) + hyperlinkEnd + " for it\r\n"
        )

        try TerminalClick.click(terminal.view, column: 6, row: row, in: grid, modifierFlags: .command)

        #expect(terminal.openedLinks == [target])
    }

    @Test(arguments: cases)
    func rightClickingEitherRowOfABrokenURLHandsTheMenuAllOfIt(_ engine: TerminalEngine, row: Int) async throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        let grid = try await terminal.grid()
        terminal.show(Self.mouseReportingOn)
        let url = Self.longURL(for: grid)
        terminal.show(Self.brokenRows(showing: url, in: grid))

        let rightClick = try TerminalClick.rightClick(terminal.view, column: 6, row: row, in: grid)

        #expect(terminal.view.link(under: rightClick) == url)
    }

    private static func longURL(for grid: TerminalTestGrid) -> String {
        "https://example.com/" + String(repeating: "x", count: grid.columns) + "/end"
    }

    private static func brokenRows(showing url: String, in grid: TerminalTestGrid) -> String {
        let firstRowPart = url.prefix(grid.columns - firstRowLead.count)
        return firstRowLead + firstRowPart + "\r\n" + "  " + url.dropFirst(firstRowPart.count) + " for it\r\n"
    }
}
