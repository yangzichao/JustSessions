import Carbon.HIToolbox

/// The punctuation keys of a US keyboard, which Chinese and Japanese input methods keep in place while they type
/// full-width punctuation for them.
enum USKeyboardPunctuation {
    static func character(atKeyCode keyCode: Int, withShift: Bool) -> Character? {
        guard let characters = charactersByKeyCode[keyCode] else { return nil }
        return withShift ? characters.shifted : characters.unshifted
    }

    static func isInputMethodPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x00B7, 0x2000...0x206F, 0x3000...0x303F, 0xFF00...0xFFEF: true
        default: false
        }
    }

    private static let charactersByKeyCode: [Int: (unshifted: Character, shifted: Character)] = [
        kVK_ANSI_Slash: ("/", "?"),
        kVK_ANSI_Minus: ("-", "_"),
        kVK_ANSI_Equal: ("=", "+"),
        kVK_ANSI_Period: (".", ">"),
        kVK_ANSI_Comma: (",", "<"),
        kVK_ANSI_Semicolon: (";", ":"),
        kVK_ANSI_Quote: ("'", "\""),
        kVK_ANSI_Grave: ("`", "~"),
        kVK_ANSI_LeftBracket: ("[", "{"),
        kVK_ANSI_RightBracket: ("]", "}"),
        kVK_ANSI_Backslash: ("\\", "|"),
    ]
}
