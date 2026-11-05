import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// Who has the keyboard as a tab's find bar opens and closes, with the tab's view in a window as the app shows it.
/// A selected tab's terminal takes the keyboard a moment after it appears, so tests wait for that before opening the
/// bar, as a person would. Each wait lays the window out on every check, as `SplitWorkspace.settleLayout()` does, so
/// SwiftUI applies its focus changes even when a full run keeps the main queue too busy to get to them: polling alone
/// timed out at 120 seconds on a loaded Mac, at a different step each time.
@MainActor
@Suite(.serialized)
struct TerminalFindBarFocusTests {
    @MainActor
    private final class Fixture {
        let window: NSWindow
        let tab: TerminalSession
        var focusCount = 0

        init(isActive: Bool = true) {
            _ = NSApplication.shared
            tab = TerminalSession(
                engine: .swiftTerm,
                conversation: nil,
                provider: nil,
                projectPath: "/tmp/terminal-find",
                action: nil,
                displayTitle: "Find focus",
                command: NativeCLICommand(executablePath: "/bin/cat", arguments: [], workingDirectory: "/tmp", environment: [])
            )
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: TerminalWorkspaceView(
                session: tab,
                isShown: true,
                isActive: isActive,
                onReconnect: nil,
                onCheckHost: nil,
                onFocus: { [unowned self] in focusCount += 1 },
                makeContextMenu: { _ in NSMenu() },
                onOpenLink: { _ in }
            ))
            window.makeKeyAndOrderFront(nil)
        }

        var findFieldHasTheKeyboard: Bool {
            guard let fieldEditor = window.firstResponder as? NSTextView,
                  let field = fieldEditor.delegate as? NSTextField else { return false }
            return field.isDescendant(of: window.contentView!)
        }

        var terminalHasTheKeyboard: Bool { window.firstResponder === tab.terminalView }

        /// Waits for the condition as `expectEventually` does, laying the window out before each check. A failure says
        /// who had the keyboard and how far the bar got, since the wait has still run out in a full run now and then.
        func expectEventually(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
            let clock = ContinuousClock()
            let deadline = clock.now + .seconds(120)
            while true {
                window.contentView!.layoutSubtreeIfNeeded()
                if condition() || clock.now >= deadline { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(condition(), "\(keyboardState)", sourceLocation: sourceLocation)
        }

        private var keyboardState: String {
            let firstResponder = window.firstResponder.map { String(describing: type(of: $0)) } ?? "none"
            return "first responder: \(firstResponder), bar shown: \(tab.findState.isPresented), "
                + "field focused: \(tab.findState.isFieldFocused), focus count: \(focusCount), "
                + "window visible: \(window.isVisible), occluded: \(!window.occlusionState.contains(.visible))"
        }

        func tearDown() {
            tab.close()
            window.close()
        }
    }

    @Test func showingTheBarGivesItsFieldTheKeyboardAndClosingGivesItBack() async throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        try await fixture.expectEventually { fixture.terminalHasTheKeyboard }

        fixture.tab.findState.show()

        try await fixture.expectEventually { fixture.findFieldHasTheKeyboard && fixture.tab.findState.isFieldFocused }

        fixture.tab.findState.close()

        try await fixture.expectEventually { fixture.terminalHasTheKeyboard }
        #expect(!fixture.tab.findState.isFieldFocused)
    }

    /// ⌘F with the bar open but the terminal typing puts the keyboard back in the field.
    @Test func showingTheOpenBarAgainTakesTheKeyboardBack() async throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        try await fixture.expectEventually { fixture.terminalHasTheKeyboard }
        fixture.tab.findState.show()
        try await fixture.expectEventually { fixture.findFieldHasTheKeyboard }
        fixture.window.makeFirstResponder(fixture.tab.terminalView)
        try await fixture.expectEventually { !fixture.tab.findState.isFieldFocused }

        fixture.tab.findState.show()

        try await fixture.expectEventually { fixture.findFieldHasTheKeyboard && fixture.tab.findState.isFieldFocused }
    }

    /// In a split, the field of the pane that is not selected selects its tab when it takes the keyboard.
    @Test func theFieldOfAPaneNotSelectedSelectsItsTab() async throws {
        let fixture = Fixture(isActive: false)
        defer { fixture.tearDown() }

        fixture.tab.findState.show()

        try await fixture.expectEventually { fixture.findFieldHasTheKeyboard }
        try await fixture.expectEventually { fixture.focusCount == 1 }
    }
}
