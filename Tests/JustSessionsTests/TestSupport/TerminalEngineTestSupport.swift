import AppKit
import Foundation

@testable import JustSessions

extension TerminalEngineStore {
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
    var otherEngine: TerminalEngine {
        switch self {
        case .ghostty: .swiftTerm
        case .swiftTerm: .ghostty
        }
    }

    @MainActor
    func draws(_ terminalView: any TabTerminalView) -> Bool {
        switch self {
        case .ghostty: terminalView is GhosttyTabTerminalView
        case .swiftTerm: terminalView is SelectableTerminalView
        }
    }

    @MainActor
    func makeTabTerminalView(
        frame: NSRect,
        appearanceStore: TerminalAppearanceStore,
        themeStore: AppThemeStore,
        optionKeyStore: TerminalOptionKeyStore = .shared
    ) -> any TabTerminalView {
        switch self {
        case .ghostty:
            GhosttyTabTerminalView(frame: frame, appearanceStore: appearanceStore, themeStore: themeStore, optionKeyStore: optionKeyStore)
        case .swiftTerm:
            SelectableTerminalView(frame: frame, appearanceStore: appearanceStore, themeStore: themeStore, optionKeyStore: optionKeyStore)
        }
    }
}

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
