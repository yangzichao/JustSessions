import AppKit
import Carbon.HIToolbox

/// Ctrl-/, Ctrl-7, and Ctrl-_ all send 0x1f, which tmux names Ctrl-_ and re-encodes as `CSI 95;5u` for a CLI that asks
/// for modifyOtherKeys, such as Codex; SwiftTerm sends nothing for Ctrl-/ or Ctrl-Return at all. Letters, Space, and
/// Tab keep each engine's own bytes, which tmux names correctly.
enum TerminalControlKey: Equatable {
    case punctuationOrDigit(Character)
    /// Control with `[`, `]`, or `\`, whose legacy bytes, Esc, GS, and FS, every terminal and tmux agree on.
    case bracketOrBackslash(Character)
    case underscore
    case returnKey(withShift: Bool)
    case backspace

    init?(_ event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])
        guard modifiers == .control || modifiers == [.control, .shift] else { return nil }
        let withShift = modifiers.contains(.shift)
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            self = .returnKey(withShift: withShift)
            return
        case kVK_Delete:
            guard !withShift else { return nil }
            self = .backspace
            return
        default:
            break
        }
        switch (Self.character(of: event, withShift: withShift), withShift) {
        case (let character?, false) where Self.punctuationAndDigits.contains(character):
            self = .punctuationOrDigit(character)
        case (let character?, false) where Self.bracketsAndBackslash.contains(character):
            self = .bracketOrBackslash(character)
        case ("_", true):
            self = .underscore
        default:
            return nil
        }
    }

    /// tmux passes `CSI u` on to a CLI that asks for modifyOtherKeys and gives any other CLI the key's legacy byte where
    /// it has one.
    var bytesForTmux: String {
        switch self {
        case .punctuationOrDigit(let character): Self.csiU(codepoint: character.asciiValue.map(Int.init) ?? 0, withShift: false)
        case .bracketOrBackslash(let character): Self.legacyControlCharacter(for: character)
        case .underscore: "\u{1F}"
        case .returnKey(let withShift): Self.csiU(codepoint: 13, withShift: withShift)
        case .backspace: Self.csiU(codepoint: 127, withShift: false)
        }
    }

    /// What a terminal without tmux in between sends, as kitty and Ghostty do, for a SwiftTerm tab, which sends
    /// nothing for most of these.
    var legacyBytes: String? {
        switch self {
        case .punctuationOrDigit(let character): Self.legacyBytesForPunctuationAndDigits[character]
        case .bracketOrBackslash(let character): Self.legacyControlCharacter(for: character)
        case .underscore: "\u{1F}"
        case .returnKey, .backspace: nil
        }
    }

    private static let punctuationAndDigits: Set<Character> = [
        "/", "-", "=", ".", ",", ";", "'", "`", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    ]
    private static let bracketsAndBackslash: Set<Character> = ["[", "]", "\\"]
    /// kitty's table, which Ghostty repeats, with Ctrl-- as Ctrl-_, as xterm and Terminal send it.
    private static let legacyBytesForPunctuationAndDigits: [Character: String] = [
        "/": "\u{1F}", "-": "\u{1F}", "2": "\u{00}", "3": "\u{1B}", "4": "\u{1C}", "5": "\u{1D}", "6": "\u{1E}", "7": "\u{1F}",
        "8": "\u{7F}",
    ]

    private static func legacyControlCharacter(for character: Character) -> String {
        String(UnicodeScalar((character.asciiValue ?? 0) & 0x1F))
    }

    private static func csiU(codepoint: Int, withShift: Bool) -> String {
        "\u{1B}[\(codepoint);\(withShift ? 6 : 5)u"
    }

    /// An input method such as Pinyin types full-width punctuation, `【` for `[`, so for those the key's character on a
    /// US keyboard stands in.
    private static func character(of event: NSEvent, withShift: Bool) -> Character? {
        guard let typed = event.charactersIgnoringModifiers, !typed.isEmpty else { return nil }
        if typed.unicodeScalars.count == 1, let scalar = typed.unicodeScalars.first, scalar.isASCII {
            return Character(scalar)
        }
        guard typed.unicodeScalars.allSatisfy(USKeyboardPunctuation.isInputMethodPunctuation) else { return nil }
        return USKeyboardPunctuation.character(atKeyCode: Int(event.keyCode), withShift: withShift)
    }
}
