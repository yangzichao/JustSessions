import AppKit
import Carbon.HIToolbox

/// A key pressed with Control, as macOS delivers it on a US keyboard or with Pinyin, which types full-width punctuation,
/// and the bytes a program should receive for it.
struct ControlKeyPress {
    // periphery:ignore - names the key in parameterized test results.
    let name: String
    let keyCode: Int
    let withShift: Bool
    let characters: String
    let charactersIgnoringModifiers: String
    /// What a CLI in tmux receives once it asks for modifyOtherKeys 2, as Codex, Claude Code, and Pi do.
    let bytesForCLIAskingForModifyOtherKeys: String
    /// What a CLI in tmux receives otherwise, or with modifyOtherKeys 1, as OpenCode asks for.
    let bytesForLegacyCLI: String
    let bytesWithoutTmux: String?

    static let slash = ControlKeyPress(
        name: "Ctrl-/", keyCode: kVK_ANSI_Slash, withShift: false, characters: "/", charactersIgnoringModifiers: "/",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[47;5u", bytesForLegacyCLI: "\u{1f}", bytesWithoutTmux: "\u{1f}"
    )
    static let minus = ControlKeyPress(
        name: "Ctrl--", keyCode: kVK_ANSI_Minus, withShift: false, characters: "\u{1f}", charactersIgnoringModifiers: "-",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[45;5u", bytesForLegacyCLI: "\u{1b}[45;5u", bytesWithoutTmux: "\u{1f}"
    )
    static let underscore = ControlKeyPress(
        name: "Ctrl-_", keyCode: kVK_ANSI_Minus, withShift: true, characters: "\u{1f}", charactersIgnoringModifiers: "_",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[95;5u", bytesForLegacyCLI: "\u{1f}", bytesWithoutTmux: "\u{1f}"
    )
    static let seven = ControlKeyPress(
        name: "Ctrl-7", keyCode: kVK_ANSI_7, withShift: false, characters: "7", charactersIgnoringModifiers: "7",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[55;5u", bytesForLegacyCLI: "\u{1f}", bytesWithoutTmux: "\u{1f}"
    )
    static let two = ControlKeyPress(
        name: "Ctrl-2", keyCode: kVK_ANSI_2, withShift: false, characters: "2", charactersIgnoringModifiers: "2",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[50;5u", bytesForLegacyCLI: "\u{00}", bytesWithoutTmux: "\u{00}"
    )
    static let equals = ControlKeyPress(
        name: "Ctrl-=", keyCode: kVK_ANSI_Equal, withShift: false, characters: "=", charactersIgnoringModifiers: "=",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[61;5u", bytesForLegacyCLI: "\u{1b}[61;5u", bytesWithoutTmux: nil
    )
    static let returnKey = ControlKeyPress(
        name: "Ctrl-Return", keyCode: kVK_Return, withShift: false, characters: "\r", charactersIgnoringModifiers: "\r",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[13;5u", bytesForLegacyCLI: "\u{1b}[13;5u", bytesWithoutTmux: nil
    )
    static let shiftReturnKey = ControlKeyPress(
        name: "Ctrl-Shift-Return", keyCode: kVK_Return, withShift: true, characters: "\r", charactersIgnoringModifiers: "\r",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[13;6u", bytesForLegacyCLI: "\u{1b}[13;6u", bytesWithoutTmux: nil
    )
    static let backspace = ControlKeyPress(
        name: "Ctrl-Backspace", keyCode: kVK_Delete, withShift: false, characters: "\u{7f}", charactersIgnoringModifiers: "\u{7f}",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[127;5u", bytesForLegacyCLI: "\u{1b}[127;5u", bytesWithoutTmux: nil
    )
    static let leftBracket = ControlKeyPress(
        name: "Ctrl-[", keyCode: kVK_ANSI_LeftBracket, withShift: false, characters: "\u{1b}", charactersIgnoringModifiers: "[",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}", bytesForLegacyCLI: "\u{1b}", bytesWithoutTmux: "\u{1b}"
    )
    static let rightBracket = ControlKeyPress(
        name: "Ctrl-]", keyCode: kVK_ANSI_RightBracket, withShift: false, characters: "\u{1d}", charactersIgnoringModifiers: "]",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[93;5u", bytesForLegacyCLI: "\u{1d}", bytesWithoutTmux: "\u{1d}"
    )
    static let pinyinLeftBracket = ControlKeyPress(
        name: "Pinyin Ctrl-【", keyCode: kVK_ANSI_LeftBracket, withShift: false, characters: "\u{1b}", charactersIgnoringModifiers: "【",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}", bytesForLegacyCLI: "\u{1b}", bytesWithoutTmux: "\u{1b}"
    )
    static let pinyinBackslash = ControlKeyPress(
        name: "Pinyin Ctrl-、", keyCode: kVK_ANSI_Backslash, withShift: false, characters: "\u{1c}", charactersIgnoringModifiers: "、",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[92;5u", bytesForLegacyCLI: "\u{1c}", bytesWithoutTmux: "\u{1c}"
    )
    static let pinyinPeriod = ControlKeyPress(
        name: "Pinyin Ctrl-。", keyCode: kVK_ANSI_Period, withShift: false, characters: ".", charactersIgnoringModifiers: "。",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[46;5u", bytesForLegacyCLI: "\u{1b}[46;5u", bytesWithoutTmux: nil
    )
    static let pinyinUnderscore = ControlKeyPress(
        name: "Pinyin Ctrl-——", keyCode: kVK_ANSI_Minus, withShift: true, characters: "\u{1f}", charactersIgnoringModifiers: "——",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[95;5u", bytesForLegacyCLI: "\u{1f}", bytesWithoutTmux: "\u{1f}"
    )
    static let letterA = ControlKeyPress(
        name: "Ctrl-A", keyCode: kVK_ANSI_A, withShift: false, characters: "\u{01}", charactersIgnoringModifiers: "a",
        bytesForCLIAskingForModifyOtherKeys: "\u{1b}[97;5u", bytesForLegacyCLI: "\u{01}", bytesWithoutTmux: "\u{01}"
    )

    static let all: [ControlKeyPress] = [
        slash, minus, underscore, seven, two, equals, returnKey, shiftReturnKey, backspace, leftBracket, rightBracket,
        pinyinLeftBracket, pinyinBackslash, pinyinPeriod, pinyinUnderscore, letterA,
    ]

    func event(windowNumber: Int) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: withShift ? [.control, .shift] : .control,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )!
    }

    /// As AppKit delivers a key with Control: to `performKeyEquivalent` first, then to `keyDown` unless a view took it.
    @MainActor
    func press(in view: NSView, windowNumber: Int) {
        let event = event(windowNumber: windowNumber)
        if !view.performKeyEquivalent(with: event) { view.keyDown(with: event) }
    }

    static func readable(_ bytes: String) -> String {
        bytes.unicodeScalars.map { scalar in
            switch scalar.value {
            case 0x1b: " ESC"
            case 0x20..<0x7f: String(scalar)
            default: String(format: " 0x%02x", scalar.value)
            }
        }.joined()
    }
}
