import AppKit
import Carbon.HIToolbox
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TerminalEditingKeyTests {
    @Test(arguments: TerminalEngine.allCases)
    func commandKeysSendTheLineEditingControlKeys(_ engine: TerminalEngine) async throws {
        let fixture = try KeyRecordingTerminalFixture(engine: engine)
        defer { fixture.tearDown() }
        try await fixture.start()

        for key in Self.commandKeys(windowNumber: fixture.window.windowNumber) {
            #expect(fixture.terminalView.performKeyEquivalent(with: key))
        }

        let expected = "\u{01}\u{05}\u{15}\u{1F}"
        try await expectEventually { fixture.receivedInput.utf8.count >= expected.utf8.count }
        #expect(fixture.receivedInput == expected, "Received bytes: \(Array(fixture.receivedInput.utf8))")
    }

    /// AppKit offers a key with Command to every view in the window, so a split pane without the keyboard leaves it.
    @Test(arguments: TerminalEngine.allCases)
    func aTerminalWithoutTheKeyboardLeavesTheKeys(_ engine: TerminalEngine) async throws {
        let fixture = try KeyRecordingTerminalFixture(engine: engine)
        defer { fixture.tearDown() }
        try await fixture.start()
        fixture.window.makeFirstResponder(nil)

        for key in Self.commandKeys(windowNumber: fixture.window.windowNumber) {
            #expect(!fixture.terminalView.performKeyEquivalent(with: key))
        }

        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.receivedInput.isEmpty)
    }

    @Test func whileAnInputMethodComposesTextASwiftTermTerminalLeavesTheKeysToIt() throws {
        let fixture = try KeyRecordingTerminalFixture(engine: .swiftTerm)
        defer { fixture.tearDown() }
        let terminalView = try #require(fixture.terminalView as? SelectableTerminalView)
        terminalView.setMarkedText(
            "ni", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(terminalView.hasMarkedText())

        for key in Self.commandKeys(windowNumber: fixture.window.windowNumber) {
            #expect(!terminalView.performKeyEquivalent(with: key))
        }
    }

    @Test func aSwiftTermTerminalLeavesTheBookmarkShortcutsToTheMenu() async throws {
        let fixture = try KeyRecordingTerminalFixture(engine: .swiftTerm)
        defer { fixture.tearDown() }
        try await fixture.start()
        let windowNumber = fixture.window.windowNumber

        for key in [
            Self.key(kVK_ANSI_D, "d", modifiers: .command, windowNumber: windowNumber),
            Self.key(kVK_ANSI_Quote, "'", modifiers: .command, windowNumber: windowNumber),
            Self.key(kVK_ANSI_Quote, "\"", modifiers: [.command, .shift], windowNumber: windowNumber),
        ] {
            #expect(!fixture.terminalView.performKeyEquivalent(with: key))
        }

        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.receivedInput.isEmpty, "Received bytes: \(Array(fixture.receivedInput.utf8))")
    }

    @Test func onlyTheKeysWithCommandAloneAreEditingKeys() {
        #expect(
            Self.commandKeys(windowNumber: 0).map(TerminalEditingKey.init) == [
                .moveToLineStart, .moveToLineEnd, .deleteToLineStart, .undo,
            ])
        #expect(TerminalEditingKey(Self.key(kVK_ANSI_Z, "z", modifiers: [.command, .shift], windowNumber: 0)) == nil)
        for modifiers: NSEvent.ModifierFlags in [[.command, .option], [.command, .control], []] {
            #expect(TerminalEditingKey(Self.leftArrow(modifiers: modifiers.union(.function), windowNumber: 0)) == nil)
        }
        #expect(TerminalEditingKey(Self.key(kVK_ANSI_A, "a", modifiers: .command, windowNumber: 0)) == nil)
    }

    /// ⌘←, ⌘→, ⌘Delete, and ⌘Z as a US keyboard sends them; the arrows come with the function and keypad flags.
    private static func commandKeys(windowNumber: Int) -> [NSEvent] {
        let arrowModifiers: NSEvent.ModifierFlags = [.command, .function, .numericPad]
        return [
            leftArrow(modifiers: arrowModifiers, windowNumber: windowNumber),
            key(kVK_RightArrow, functionKey(NSRightArrowFunctionKey), modifiers: arrowModifiers, windowNumber: windowNumber),
            key(kVK_Delete, "\u{7F}", modifiers: .command, windowNumber: windowNumber),
            key(kVK_ANSI_Z, "z", modifiers: .command, windowNumber: windowNumber),
        ]
    }

    private static func leftArrow(modifiers: NSEvent.ModifierFlags, windowNumber: Int) -> NSEvent {
        key(kVK_LeftArrow, functionKey(NSLeftArrowFunctionKey), modifiers: modifiers, windowNumber: windowNumber)
    }

    private static func functionKey(_ character: Int) -> String {
        String(UnicodeScalar(UInt16(character))!)
    }

    private static func key(_ keyCode: Int, _ characters: String, modifiers: NSEvent.ModifierFlags, windowNumber: Int) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )!
    }
}
