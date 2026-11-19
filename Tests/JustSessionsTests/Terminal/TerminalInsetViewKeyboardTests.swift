import AppKit
import Testing

@testable import JustSessions

/// A selected tab's terminal takes the keyboard even when SwiftUI adds its view to the window only after the tab was
/// given the keyboard, as it can when the app is busy; see `TerminalInsetView.takeKeyboard()`.
@MainActor
struct TerminalInsetViewKeyboardTests {
    @Test func aTerminalGivenTheKeyboardBeforeItIsInAWindowTakesItThere() {
        let (window, insetView, terminal) = makeTerminal()
        defer { window.close() }

        insetView.takeKeyboard()
        #expect(window.firstResponder !== terminal)
        window.contentView = insetView

        #expect(window.firstResponder === terminal)
        #expect(!insetView.takesKeyboardInWindow)
    }

    @Test func aTerminalInAWindowTakesTheKeyboardAtOnce() {
        let (window, insetView, terminal) = makeTerminal()
        defer { window.close() }
        window.contentView = insetView

        insetView.takeKeyboard()

        #expect(window.firstResponder === terminal)
    }

    /// A tab deselected before its view reaches the window leaves the keyboard where it is.
    @Test func aTerminalNoLongerOwedTheKeyboardLeavesItAlone() {
        let (window, insetView, terminal) = makeTerminal()
        defer { window.close() }

        insetView.takeKeyboard()
        insetView.takesKeyboardInWindow = false
        window.contentView = insetView

        #expect(window.firstResponder !== terminal)
    }

    private func makeTerminal() -> (NSWindow, TerminalInsetView, SelectableTerminalView) {
        _ = NSApplication.shared
        let frame = NSRect(x: 100, y: 100, width: 400, height: 300)
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        let terminal = SelectableTerminalView(frame: NSRect(origin: .zero, size: frame.size))
        return (window, TerminalInsetView(terminalView: terminal), terminal)
    }
}
