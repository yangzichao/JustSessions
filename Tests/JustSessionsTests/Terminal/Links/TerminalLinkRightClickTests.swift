import AppKit
import Testing

@testable import JustSessions

/// A right-click on a link hands the menu the same link a ⌘-click there would open, whichever engine draws the
/// terminal, and whether or not a program takes the mouse; see `TerminalLinkClickTests`.
@MainActor
@Suite(.serialized)
struct TerminalLinkRightClickTests {
    private static let mouseReportingOn = "\u{1B}[?1000h\u{1B}[?1006h"

    @Test(arguments: TerminalLinkClickTests.mouseReportingCases)
    func theMenuGetsTheURLUnderThePointer(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("https://example.com/docs?page=2 is the guide\r\n")

        #expect(linkHandedToTheMenu(rightClicking: terminal, column: 3) == "https://example.com/docs?page=2")
    }

    @Test(arguments: TerminalLinkClickTests.mouseReportingCases)
    func theMenuGetsThePathUnderThePointerWithItsLineNumber(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("Sources/App/main.swift:42 was edited\r\n")

        #expect(linkHandedToTheMenu(rightClicking: terminal, column: 3) == "Sources/App/main.swift:42")
    }

    @Test(arguments: TerminalLinkClickTests.mouseReportingCases)
    func theMenuGetsAHyperlinksTarget(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("\u{1B}]8;;https://example.com/target\u{1B}\\the release notes\u{1B}]8;;\u{1B}\\\r\n")

        #expect(linkHandedToTheMenu(rightClicking: terminal, column: 3) == "https://example.com/target")
    }

    @Test(arguments: TerminalLinkClickTests.mouseReportingCases)
    func theMenuGetsNoLinkOverPlainText(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("plain words https://example.com\r\n")

        #expect(linkHandedToTheMenu(rightClicking: terminal, column: 3) == .some(nil))
    }

    /// The margin around the terminal shows the terminal's menu too, but has no text.
    @Test(arguments: TerminalEngine.allCases)
    func theMarginHasNoLink(_ engine: TerminalEngine) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        terminal.show("https://example.com/docs\r\n")

        let outside = try TerminalClick.rightClick(terminal.view, at: CGPoint(x: -6, y: terminal.view.bounds.height - 4))

        #expect(terminal.view.link(under: outside) == nil)
    }

    /// Finding the link leaves the terminal as it was: a plain click afterwards opens nothing.
    @Test(arguments: TerminalLinkClickTests.mouseReportingCases)
    func findingTheLinkOpensNothing(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("https://example.com/docs\r\n")

        _ = linkHandedToTheMenu(rightClicking: terminal, column: 3)
        try TerminalClick.click(terminal.view, column: 3, modifierFlags: [])

        #expect(terminal.openedLinks.isEmpty)
    }

    /// What the view hands `makeContextMenu` for a right-click over `column` of the first row; nil when it builds no
    /// menu, and `.some(nil)` when it hands over no link.
    private func linkHandedToTheMenu(rightClicking terminal: ClickableTerminal, column: Int) -> String?? {
        var handedLinks: [String?] = []
        terminal.view.makeContextMenu = { link in
            handedLinks.append(link)
            return NSMenu()
        }
        defer { terminal.view.makeContextMenu = nil }
        guard let rightClick = try? TerminalClick.rightClick(terminal.view, column: column),
            terminal.view.menu(for: rightClick) != nil
        else { return nil }
        return handedLinks.last
    }
}
