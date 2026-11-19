import AppKit
import Testing

@testable import JustSessions

/// A split chooser takes the keyboard from the terminal beside it, as Chrome's split view page takes it from the tab
/// beside it, so ↑, ↓, and Return reach its list rather than the CLI. Whatever ends it hands the keyboard to a terminal
/// again: the chosen tab's, or, once closed, its own tab's.
@MainActor
struct TerminalSplitChooserFocusTests {
    @Test(arguments: TerminalEngine.allCases)
    func theKeysPickATabFromTheListAndItsTerminalTakesTheKeyboard(_ engine: TerminalEngine) async throws {
        let workspace = try SplitWorkspace(engine: engine)
        defer { workspace.close() }
        let store = workspace.store
        let first = workspace.open()
        let second = workspace.open()
        let third = workspace.open()
        store.selectTerminal(first.id)
        try await workspace.show()
        workspace.window.makeFirstResponder(first.terminalView)
        try #require(workspace.window.firstResponder === first.terminalView)

        store.openSplitChooser()
        try await workspace.settleLayout()
        #expect(store.splitChooserCandidates.map(\.id) == [third.id, second.id])
        #expect(!terminalViews(of: [first, second, third]).contains { $0 === workspace.window.firstResponder })

        try workspace.press(.downArrow)
        try workspace.press(.return)
        try await workspace.settleLayout()

        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: first.id, right: second.id))
        #expect(store.selectedTerminalID == second.id)
        #expect(workspace.window.firstResponder === second.terminalView)
    }

    @Test(arguments: TerminalEngine.allCases)
    func closingTheChooserGivesItsTabTheKeyboardBack(_ engine: TerminalEngine) async throws {
        let workspace = try SplitWorkspace(engine: engine)
        defer { workspace.close() }
        let store = workspace.store
        let first = workspace.open()
        let second = workspace.open()
        store.selectTerminal(first.id)
        try await workspace.show()
        workspace.window.makeFirstResponder(first.terminalView)
        store.openSplitChooser()
        try await workspace.settleLayout()
        let chooser = try #require(store.shownSplitChooser)
        #expect(!terminalViews(of: [first, second]).contains { $0 === workspace.window.firstResponder })

        store.closeSplitChooser(chooser.id)
        try await workspace.settleLayout()

        #expect(workspace.window.firstResponder === first.terminalView)
        #expect(store.selectedTerminalID == first.id)
    }

    private func terminalViews(of tabs: [TerminalSession]) -> [NSView] {
        tabs.map(\.terminalView)
    }
}

extension SplitWorkspace {
    fileprivate enum Key {
        case downArrow, `return`

        var characters: String {
            switch self {
            case .downArrow: String(UnicodeScalar(NSDownArrowFunctionKey)!)
            case .return: "\r"
            }
        }

        var keyCode: UInt16 {
            switch self {
            case .downArrow: 125
            case .return: 36
            }
        }

        var modifierFlags: NSEvent.ModifierFlags {
            switch self {
            case .downArrow: [.numericPad, .function]
            case .return: []
            }
        }
    }

    /// Sends the key to the window's first responder, as typing it would.
    fileprivate func press(_ key: Key) throws {
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: key.modifierFlags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                characters: key.characters,
                charactersIgnoringModifiers: key.characters,
                isARepeat: false,
                keyCode: key.keyCode
            ))
        window.sendEvent(event)
    }
}
