import AppKit
import Testing

@testable import JustSessions

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
