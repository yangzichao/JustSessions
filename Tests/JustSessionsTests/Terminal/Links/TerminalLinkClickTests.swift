import AppKit
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TerminalLinkClickTests {
    nonisolated static let mouseReportingCases: [(TerminalEngine, Bool)] = TerminalEngine.allCases.flatMap { [($0, false), ($0, true)] }
    private static let mouseReportingOn = "\u{1B}[?1000h\u{1B}[?1006h"

    @Test(arguments: mouseReportingCases)
    func commandClickingAURLHandsItOver(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("https://example.com/docs?page=2 is the guide\r\n")

        try TerminalClick.click(terminal.view, column: 3, modifierFlags: .command)

        #expect(terminal.openedLinks == ["https://example.com/docs?page=2"])
    }

    @Test(arguments: mouseReportingCases)
    func commandClickingAPathHandsItOverWithItsLineNumber(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("Sources/App/main.swift:42 was edited\r\n")

        try TerminalClick.click(terminal.view, column: 3, modifierFlags: .command)

        #expect(terminal.openedLinks == ["Sources/App/main.swift:42"])
    }

    @Test(arguments: mouseReportingCases)
    func commandClickingAHyperlinkHandsOverItsTargetNotItsText(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("\u{1B}]8;;https://example.com/target\u{1B}\\the release notes\u{1B}]8;;\u{1B}\\\r\n")

        try TerminalClick.click(terminal.view, column: 3, modifierFlags: .command)

        #expect(terminal.openedLinks == ["https://example.com/target"])
    }

    @Test(arguments: mouseReportingCases)
    func commandClickingALinkWorksWithTextSelected(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("https://example.com/docs\r\nmore output\r\n")
        terminal.view.selectAll(nil)
        #expect(terminal.view.selectionActive)

        try TerminalClick.click(terminal.view, column: 3, modifierFlags: .command)

        #expect(terminal.openedLinks == ["https://example.com/docs"])
    }

    @Test(arguments: mouseReportingCases)
    func aClickWithoutCommandOpensNothing(_ engine: TerminalEngine, programTakesTheMouse: Bool) throws {
        let terminal = try ClickableTerminal(engine: engine)
        defer { terminal.close() }
        if programTakesTheMouse { terminal.show(Self.mouseReportingOn) }
        terminal.show("https://example.com/docs\r\n")

        try TerminalClick.click(terminal.view, column: 3, modifierFlags: [])

        #expect(terminal.openedLinks.isEmpty)
    }
}
