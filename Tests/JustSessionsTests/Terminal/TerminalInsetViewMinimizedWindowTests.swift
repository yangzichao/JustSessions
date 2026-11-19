import AppKit
import Testing

@testable import JustSessions

/// A terminal in a minimized window batches its output and stops drawing, as a hidden tab does, and picks up again
/// when the window comes back. `SelectableTerminalView.setWorkspaceActive(false)` hides the view, which is what's
/// checked here; see `TerminalInsetView.isShown`.
@MainActor
struct TerminalInsetViewMinimizedWindowTests {
    @Test func aShownTerminalStopsWhileItsWindowIsMinimizedAndResumesAfter() async throws {
        _ = NSApplication.shared
        let (window, insetView, terminal) = makeWindow()
        defer { window.close() }
        insetView.isShown = true
        #expect(!terminal.isHidden)

        window.miniaturize(nil)
        try await expectEventually { window.isMiniaturized && terminal.isHidden }
        #expect(terminal.isHidden)

        window.deminiaturize(nil)
        try await expectEventually { !window.isMiniaturized && !terminal.isHidden }
        #expect(!terminal.isHidden)
    }

    @Test func aHiddenTabStaysHiddenWhateverItsWindowDoes() async throws {
        _ = NSApplication.shared
        let (window, insetView, terminal) = makeWindow()
        defer { window.close() }
        insetView.isShown = false
        #expect(terminal.isHidden)

        window.miniaturize(nil)
        try await expectEventually { window.isMiniaturized }
        #expect(terminal.isHidden)
        window.deminiaturize(nil)
        try await expectEventually { !window.isMiniaturized }
        #expect(terminal.isHidden)

        insetView.isShown = true
        #expect(!terminal.isHidden)
    }

    /// A tab dragged into a minimized window follows that window.
    @Test func aTerminalMovedIntoAMinimizedWindowStopsThere() async throws {
        _ = NSApplication.shared
        let (first, insetView, terminal) = makeWindow()
        defer { first.close() }
        let second = NSWindow(
            contentRect: NSRect(x: 300, y: 300, width: 400, height: 300), styleMask: [.titled, .miniaturizable], backing: .buffered,
            defer: false)
        second.isReleasedWhenClosed = false
        second.orderFrontRegardless()
        defer { second.close() }
        second.miniaturize(nil)
        try await expectEventually { second.isMiniaturized }
        #expect(!terminal.isHidden)

        insetView.removeFromSuperview()
        second.contentView = insetView
        #expect(terminal.isHidden)

        second.deminiaturize(nil)
        try await expectEventually { !second.isMiniaturized && !terminal.isHidden }
    }

    private func makeWindow() -> (NSWindow, TerminalInsetView, SelectableTerminalView) {
        let frame = NSRect(x: 100, y: 100, width: 400, height: 300)
        let window = NSWindow(contentRect: frame, styleMask: [.titled, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let terminal = SelectableTerminalView(frame: NSRect(origin: .zero, size: frame.size))
        let insetView = TerminalInsetView(terminalView: terminal)
        window.contentView = insetView
        window.orderFrontRegardless()
        return (window, insetView, terminal)
    }
}
