import AppKit
import Carbon.HIToolbox

enum PromptSelectionTestKey {
    static func command(_ letter: String, windowNumber: Int = 0) -> NSEvent {
        let keyCodes = ["a": kVK_ANSI_A, "c": kVK_ANSI_C, "v": kVK_ANSI_V, "x": kVK_ANSI_X, "z": kVK_ANSI_Z]
        return key(keyCodes[letter] ?? kVK_ANSI_A, letter, modifiers: .command, windowNumber: windowNumber)
    }

    static func typing(_ text: String, keyCode: Int = kVK_ANSI_K, modifiers: NSEvent.ModifierFlags = [], windowNumber: Int = 0) -> NSEvent {
        key(keyCode, text, modifiers: modifiers, windowNumber: windowNumber)
    }

    static func delete(modifiers: NSEvent.ModifierFlags = [], windowNumber: Int = 0) -> NSEvent {
        key(kVK_Delete, "\u{7F}", modifiers: modifiers, windowNumber: windowNumber)
    }

    static func forwardDelete(windowNumber: Int = 0) -> NSEvent {
        key(kVK_ForwardDelete, functionKey(NSDeleteFunctionKey), modifiers: .function, windowNumber: windowNumber)
    }

    static func leftArrow(modifiers: NSEvent.ModifierFlags = [], windowNumber: Int = 0) -> NSEvent {
        key(
            kVK_LeftArrow, functionKey(NSLeftArrowFunctionKey), modifiers: modifiers.union([.function, .numericPad]),
            windowNumber: windowNumber)
    }

    static func rightArrow(modifiers: NSEvent.ModifierFlags = [], windowNumber: Int = 0) -> NSEvent {
        key(
            kVK_RightArrow, functionKey(NSRightArrowFunctionKey), modifiers: modifiers.union([.function, .numericPad]),
            windowNumber: windowNumber)
    }

    static func upArrow(windowNumber: Int = 0) -> NSEvent {
        key(kVK_UpArrow, functionKey(NSUpArrowFunctionKey), modifiers: [.function, .numericPad], windowNumber: windowNumber)
    }

    static func escape(windowNumber: Int = 0) -> NSEvent {
        key(kVK_Escape, "\u{1B}", modifiers: [], windowNumber: windowNumber)
    }

    static func returnKey(windowNumber: Int = 0) -> NSEvent {
        key(kVK_Return, "\r", modifiers: [], windowNumber: windowNumber)
    }

    static func control(_ letter: String, windowNumber: Int = 0) -> NSEvent {
        let controlCharacter = String(UnicodeScalar(letter.unicodeScalars.first!.value - 0x60)!)
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .control,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: controlCharacter,
            charactersIgnoringModifiers: letter,
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_C)
        )!
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
