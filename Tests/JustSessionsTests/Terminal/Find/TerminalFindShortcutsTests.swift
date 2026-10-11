import AppKit
import Carbon.HIToolbox
import Testing
@testable import JustSessions

/// Find's keys in a window showing a tab. Escape and Return reach the terminal's program unless the find field has the
/// keyboard, so a CLI keeps its Escape.
@MainActor
struct TerminalFindShortcutsTests {
    @MainActor
    private final class Fixture {
        let window: NSWindow
        let shortcutView = TerminalFindShortcuts.ShortcutView(frame: .zero)
        let fieldEditor = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 20))
        let findState = TerminalFindState(finder: SilentTerminalFinder())
        var findCount = 0

        init() {
            _ = NSApplication.shared
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView?.addSubview(shortcutView)
            window.contentView?.addSubview(fieldEditor)
            shortcutView.selectedTabFind = findState
            shortcutView.onFind = { [unowned self] in findCount += 1 }
        }

        func key(_ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []) -> NSEvent? {
            shortcutView.handle(SyntheticKey.event(keyCode: keyCode, characters: characters, modifiers: modifiers, window: window))
        }

        /// The find bar shows with "needle" typed and its field has the keyboard.
        func showBarWithFocusedField() {
            findState.show()
            findState.query = "needle"
            window.makeFirstResponder(fieldEditor)
            findState.isFieldFocused = true
        }

        func tearDown() {
            shortcutView.stop()
            window.close()
        }
    }

    @Test func commandFFindsInTheSelectedTab() {
        let fixture = Fixture()
        defer { fixture.tearDown() }

        #expect(fixture.key(kVK_ANSI_F, "f", .command) == nil)
        #expect(fixture.findCount == 1)
    }

    @Test func noSelectedTabLeavesEveryKeyAlone() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        fixture.shortcutView.selectedTabFind = nil

        #expect(fixture.key(kVK_ANSI_F, "f", .command) != nil)
        #expect(fixture.findCount == 0)
    }

    @Test func commandGMovesOnlyWhileTheBarShows() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        #expect(fixture.key(kVK_ANSI_G, "g", .command) != nil)

        fixture.showBarWithFocusedField()
        fixture.window.makeFirstResponder(nil)
        fixture.findState.isFieldFocused = false

        #expect(fixture.key(kVK_ANSI_G, "g", .command) == nil)
        #expect(fixture.key(kVK_ANSI_G, "G", [.command, .shift]) == nil)
    }

    @Test func returnEscapeAndShiftReturnBelongToTheFocusedField() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        fixture.showBarWithFocusedField()

        #expect(fixture.key(kVK_Return, "\r") == nil)
        #expect(fixture.key(kVK_Return, "\r", .shift) == nil)
        #expect(fixture.key(kVK_Escape, "\u{1B}") == nil)
        #expect(!fixture.findState.isPresented)
    }

    /// The bar shows, but the terminal has the keyboard: its program gets Escape and Return.
    @Test func escapeAndReturnReachTheTerminalWhileTheFieldIsNotFocused() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        fixture.showBarWithFocusedField()
        fixture.window.makeFirstResponder(nil)
        fixture.findState.isFieldFocused = false

        #expect(fixture.key(kVK_Escape, "\u{1B}") != nil)
        #expect(fixture.key(kVK_Return, "\r") != nil)
        #expect(fixture.findState.isPresented)
    }

    @Test func keysInAnotherWindowAreLeftAlone() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let otherWindow = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        otherWindow.isReleasedWhenClosed = false
        defer { otherWindow.close() }

        let event = SyntheticKey.event(keyCode: kVK_ANSI_F, characters: "f", modifiers: .command, window: otherWindow)

        #expect(fixture.shortcutView.handle(event) != nil)
        #expect(fixture.findCount == 0)
    }
}

/// A finder that counts nothing, for tests about keys rather than matches.
@MainActor
private final class SilentTerminalFinder: TerminalTextFinding {
    var onFindMatchCountChange: ((TerminalFindMatchCount?) -> Void)?
    func findText(_ query: String) {}
    func findTextAgain(_ query: String, direction: TerminalFindDirection) {}
    func endTextFind() {}
}
