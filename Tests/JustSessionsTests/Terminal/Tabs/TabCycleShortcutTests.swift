import AppKit
import Carbon.HIToolbox
import Testing
@testable import JustSessions

@MainActor
struct TabCycleShortcutTests {
    @Test func controlTabCyclesWhilePlainTabAndTerminalControlKeysRemainUntouched() {
        #expect(direction(modifiers: .control) == true)
        #expect(direction(modifiers: [.control, .shift]) == false)
        #expect(direction(modifiers: [.control, .capsLock, .function]) == true)
        for modifiers: NSEvent.ModifierFlags in [[], .shift, .command, .option, [.control, .option], [.control, .command]] {
            #expect(direction(modifiers: modifiers) == nil)
        }
        #expect(direction(modifiers: .control, keyCode: UInt16(kVK_ANSI_I)) == nil)
        #expect(direction(modifiers: .control, type: .keyUp) == nil)
    }

    private func direction(
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16 = UInt16(kVK_Tab),
        type: NSEvent.EventType = .keyDown
    ) -> Bool? {
        let event = NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0,
            context: nil, characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: keyCode
        )!
        return WorkspaceTabCycleShortcutView.cycleDirection(for: event)
    }
}
