import AppKit
import Foundation
@testable import JustSessions

extension TerminalEngineStore {
    /// A store whose tabs open with `engine`, for a test that uses one engine's own API. Its settings suite is gone
    /// once the choice is made; the store keeps the choice.
    @MainActor
    static func pinned(to engine: TerminalEngine) throws -> TerminalEngineStore {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalEngineStore(userDefaults: settings.userDefaults)
        store.setEngine(engine)
        return store
    }
}

extension TerminalEngine {
    /// The engine a test switches to, to show that a tab keeps the engine it had, or takes the one chosen now.
    var otherEngine: TerminalEngine {
        switch self {
        case .ghostty: .swiftTerm
        case .swiftTerm: .ghostty
        }
    }

    /// Whether the terminal is this engine's own view.
    @MainActor
    func draws(_ terminalView: any TabTerminalView) -> Bool {
        switch self {
        case .ghostty: terminalView is GhosttyTabTerminalView
        case .swiftTerm: terminalView is SelectableTerminalView
        }
    }

    /// A tab's terminal drawn by this engine, with the appearance settings of a test's own.
    @MainActor
    func makeTabTerminalView(frame: NSRect, appearanceStore: TerminalAppearanceStore, themeStore: AppThemeStore) -> any TabTerminalView {
        switch self {
        case .ghostty: GhosttyTabTerminalView(frame: frame, appearanceStore: appearanceStore, themeStore: themeStore)
        case .swiftTerm: SelectableTerminalView(frame: frame, appearanceStore: appearanceStore, themeStore: themeStore)
        }
    }
}

/// What a tab's terminal shows: SwiftTerm's whole buffer, or the rows of Ghostty's screen, which it fills only in a
/// window.
@MainActor
func screenText(of terminalView: any TabTerminalView) -> String {
    switch terminalView {
    case let swiftTermView as SelectableTerminalView:
        String(decoding: swiftTermView.getTerminal().getBufferAsData(), as: UTF8.self)
    case let ghosttyView as GhosttyTabTerminalView:
        ghosttyView.inMemorySession.readViewportText() ?? ""
    default:
        ""
    }
}

/// Hands `text` to the terminal as a process's output and waits until the terminal has read it.
@MainActor
func feedOutput(_ text: String, to terminalView: any TabTerminalView) {
    switch terminalView {
    case let swiftTermView as SelectableTerminalView:
        swiftTermView.feed(text: text)
    case let ghosttyView as GhosttyTabTerminalView:
        ghosttyView.inMemorySession.receive(text)
        ghosttyView.inMemorySession.waitForPendingOutput()
    default:
        break
    }
}
