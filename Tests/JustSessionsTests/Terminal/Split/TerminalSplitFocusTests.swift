import AppKit
import SwiftUI
import Testing

@testable import JustSessions

/// Reversing, swapping into, or separating a split reorders the tabs, and with them the terminals the workspace lays
/// out. The selected terminal must keep the keyboard through that: if its view were taken out of the window and put
/// back, it would resign first responder and typing would go nowhere until a click.
@MainActor
struct TerminalSplitFocusTests {
    @Test(arguments: TerminalEngine.allCases)
    func reorderingTheTabsKeepsTheKeyboardOnTheSelectedTerminal(_ engine: TerminalEngine) async throws {
        let workspace = try SplitWorkspace(engine: engine)
        defer { workspace.close() }
        let store = workspace.store
        let first = workspace.open()
        let second = workspace.open()
        let third = workspace.open()
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)
        try await workspace.show()
        workspace.window.makeFirstResponder(first.terminalView)
        try #require(workspace.window.firstResponder === first.terminalView)
        let hostsBefore = workspace.terminalHosts(of: [first, second, third])

        store.reverseSplit(split.id)
        try await workspace.settleLayout()
        #expect(store.terminalSessions.map(\.id) == [second.id, first.id, third.id])
        #expect(workspace.window.firstResponder === first.terminalView, "after reversing")

        store.moveIntoShownSplit(third.id, swappingWith: .left)
        try await workspace.settleLayout()
        #expect(store.terminalSessions.map(\.id) == [third.id, first.id, second.id])
        #expect(workspace.window.firstResponder === first.terminalView, "after swapping")

        store.separateSplit(split.id)
        try await workspace.settleLayout()
        #expect(workspace.window.firstResponder === first.terminalView, "after separating")

        #expect(workspace.terminalHosts(of: [first, second, third]) == hostsBefore)
    }
}
