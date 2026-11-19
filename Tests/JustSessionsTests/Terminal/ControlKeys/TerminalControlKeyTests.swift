import AppKit
import Carbon.HIToolbox
import Testing

@testable import JustSessions

/// Which keys with Control a tab sends itself, and what a SwiftTerm terminal without tmux sends for them; see
/// `ThisMacTmuxControlKeyTests` for a CLI in this Mac's tmux.
@MainActor
@Suite(.serialized)
struct TerminalControlKeyTests {
    @Test func eachPressIsTheKeyItNames() {
        #expect(
            ControlKeyPress.all.map { TerminalControlKey($0.event(windowNumber: 0)) } == [
                .punctuationOrDigit("/"), .punctuationOrDigit("-"), .underscore, .punctuationOrDigit("7"), .punctuationOrDigit("2"),
                .punctuationOrDigit("="), .returnKey(withShift: false), .returnKey(withShift: true), .backspace,
                .bracketOrBackslash("["), .bracketOrBackslash("]"), .bracketOrBackslash("["), .bracketOrBackslash("\\"),
                .punctuationOrDigit("."), .underscore, nil,
            ])
    }

    @Test func keysEachEngineAlreadySendsRightAreLeftToIt() {
        // Letters, Space, and Tab keep the engine's bytes, as do keys with Option or Command, Ctrl-Shift with
        // anything but - and Return, and a layout's letter that is not ASCII.
        #expect(TerminalControlKey(Self.key(kVK_Space, " ", modifiers: .control)) == nil)
        #expect(TerminalControlKey(Self.key(kVK_Tab, "\t", modifiers: .control)) == nil)
        #expect(TerminalControlKey(Self.key(kVK_ANSI_Slash, "/", modifiers: [.control, .option])) == nil)
        #expect(TerminalControlKey(Self.key(kVK_ANSI_Slash, "/", modifiers: [.control, .command])) == nil)
        #expect(TerminalControlKey(Self.key(kVK_ANSI_Slash, "/", modifiers: [])) == nil)
        #expect(TerminalControlKey(Self.key(kVK_ANSI_Slash, "?", modifiers: [.control, .shift])) == nil)
        #expect(TerminalControlKey(Self.key(kVK_ANSI_2, "@", modifiers: [.control, .shift])) == nil)
        #expect(TerminalControlKey(Self.key(kVK_Delete, "\u{7f}", modifiers: [.control, .shift])) == nil)
        #expect(TerminalControlKey(Self.key(kVK_ANSI_Semicolon, "ö", modifiers: .control)) == nil)
        #expect(TerminalControlKey(Self.key(kVK_ANSI_Grave, "§", modifiers: .control)) == nil)
    }

    @Test func aKeyIsCSIuForThisMacsTmuxAndItsLegacyByteWithout() {
        let slash = TerminalControlKey.punctuationOrDigit("/")
        #expect(slash.bytesForTmux == "\u{1b}[47;5u")
        #expect(slash.legacyBytes == "\u{1f}")
        #expect(TerminalControlKey.punctuationOrDigit("=").legacyBytes == nil)
        #expect(TerminalControlKey.bracketOrBackslash("]").bytesForTmux == "\u{1d}")
        #expect(TerminalControlKey.returnKey(withShift: true).bytesForTmux == "\u{1b}[13;6u")
        #expect(TerminalControlKey.returnKey(withShift: true).legacyBytes == nil)
        #expect(TerminalControlKey.backspace.bytesForTmux == "\u{1b}[127;5u")
    }

    @Test func aSwiftTermTerminalWithoutTmuxSendsTheLegacyBytes() async throws {
        let fixture = try KeyRecordingTerminalFixture(engine: .swiftTerm)
        defer { fixture.tearDown() }
        try await fixture.start()
        let presses = ControlKeyPress.all.filter { $0.bytesWithoutTmux != nil }

        for press in presses {
            press.press(in: fixture.terminalView, windowNumber: fixture.window.windowNumber)
        }

        let expected = presses.compactMap(\.bytesWithoutTmux).joined()
        try await expectEventually { fixture.receivedInput.utf8.count >= expected.utf8.count }
        #expect(
            fixture.receivedInput == expected,
            "Received:\(ControlKeyPress.readable(fixture.receivedInput))\nExpected:\(ControlKeyPress.readable(expected))"
        )
    }

    /// AppKit offers a key with Control to every view in the window, so a split pane without the keyboard leaves it.
    @Test(arguments: TerminalEngine.allCases)
    func aTerminalWithoutTheKeyboardLeavesTheKeys(_ engine: TerminalEngine) async throws {
        let fixture = try KeyRecordingTerminalFixture(engine: engine)
        defer { fixture.tearDown() }
        fixture.terminalView.cliRunsInTmux = true
        try await fixture.start()
        fixture.window.makeFirstResponder(nil)

        for press in [ControlKeyPress.slash, .returnKey, .backspace] {
            #expect(!fixture.terminalView.performKeyEquivalent(with: press.event(windowNumber: fixture.window.windowNumber)))
        }

        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.receivedInput.isEmpty)
    }

    @Test func whileAnInputMethodComposesTextASwiftTermTerminalLeavesTheKeysToIt() throws {
        let fixture = try KeyRecordingTerminalFixture(engine: .swiftTerm)
        defer { fixture.tearDown() }
        let terminalView = try #require(fixture.terminalView as? SelectableTerminalView)
        terminalView.cliRunsInTmux = true
        terminalView.setMarkedText(
            "ni", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0)
        )

        #expect(terminalView.bytesToSend(forControlKey: ControlKeyPress.slash.event(windowNumber: 0)) != nil)
        #expect(!terminalView.performKeyEquivalent(with: ControlKeyPress.slash.event(windowNumber: fixture.window.windowNumber)))
    }

    /// Outside tmux, Ghostty's own bytes stay.
    @Test func aGhosttyTerminalSendsControlKeysItselfOnlyInTmux() async throws {
        let fixture = try KeyRecordingTerminalFixture(engine: .ghostty)
        defer { fixture.tearDown() }
        let terminalView = try #require(fixture.terminalView as? GhosttyTabTerminalView)
        try await fixture.start()
        let slash = ControlKeyPress.slash.event(windowNumber: fixture.window.windowNumber)

        #expect(!terminalView.sendControlKeyToTmux(slash))
        terminalView.cliRunsInTmux = true
        #expect(terminalView.sendControlKeyToTmux(slash))

        try await expectEventually { !fixture.receivedInput.isEmpty }
        #expect(fixture.receivedInput == "\u{1b}[47;5u")
    }

    private static func key(_ keyCode: Int, _ charactersIgnoringModifiers: String, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: charactersIgnoringModifiers,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )!
    }
}
