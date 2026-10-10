import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// The terminal preview in Settings is drawn by the engine chosen there, and changes with it.
@MainActor
struct TerminalAppearancePreviewEngineTests {
    @Test func choosingAnotherEngineRedrawsThePreviewWithIt() async throws {
        _ = NSApplication.shared
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let engineStore = TerminalEngineStore(userDefaults: settings.userDefaults)
        let hostingView = NSHostingView(rootView: Grid {
            TerminalAppearanceSection(
                appearanceStore: TerminalAppearanceStore(userDefaults: settings.userDefaults),
                engineStore: engineStore,
                themeStore: AppThemeStore(userDefaults: settings.userDefaults)
            )
        })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        defer { window.close() }

        func previewEngines() -> [TerminalEngine] {
            hostingView.layoutSubtreeIfNeeded()
            return terminalEngines(in: hostingView)
        }

        try await expectEventually(timeout: .seconds(30)) { previewEngines() == [.swiftTerm] }

        engineStore.setEngine(.ghostty)

        try await expectEventually(timeout: .seconds(30)) { previewEngines() == [.ghostty] }
    }

    private func terminalEngines(in view: NSView) -> [TerminalEngine] {
        let engines: [TerminalEngine] = switch view {
        case is GhosttyTabTerminalView: [.ghostty]
        case is SelectableTerminalView: [.swiftTerm]
        default: []
        }
        return engines + view.subviews.flatMap(terminalEngines(in:))
    }
}
