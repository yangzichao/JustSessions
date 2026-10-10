import AppKit
import Testing
@testable import JustSessions

/// A right-click on a terminal or its margin selects its tab, as a click does, then shows the terminal's menu.
@MainActor
struct TerminalRightClickTests {
    @Test(arguments: TerminalEngine.allCases)
    func aRightClickInASplitPaneSelectsItsTabThenShowsItsMenu(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let left = fixture.openTab(engine: engine, title: "Left")
        let right = fixture.openTab(engine: engine, title: "Right")
        fixture.store.selectTerminal(left.id)
        fixture.store.splitSelectedTerminal(with: right.id)
        wireUp(right, in: fixture)

        let menu = try #require(right.terminalView.menu(for: rightClick()))

        #expect(fixture.store.selectedTerminalID == right.id)
        #expect(TerminalContextMenuFixture.titles(of: menu) == TerminalContextMenuFixture.titles(of: fixture.menu(for: right)))
    }

    @Test(arguments: TerminalEngine.allCases)
    func aRightClickInTheMarginShowsTheTerminalsMenu(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: engine, conversation: .fixture())
        wireUp(tab, in: fixture)
        let insetView = TerminalInsetView(terminalView: tab.terminalView)

        let menu = try #require(insetView.menu(for: rightClick()))

        #expect(TerminalContextMenuFixture.titles(of: menu) == TerminalContextMenuFixture.titles(of: fixture.menu(for: tab)))
    }

    /// As `WorkspaceDetailView` sets each tab's terminal up.
    private func wireUp(_ tab: TerminalSession, in fixture: TerminalContextMenuFixture) {
        tab.terminalView.onFocus = { [store = fixture.store] in store.selectTerminal(tab.id) }
        tab.terminalView.makeContextMenu = { fixture.menu(for: tab) }
    }

    private func rightClick() throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }
}
