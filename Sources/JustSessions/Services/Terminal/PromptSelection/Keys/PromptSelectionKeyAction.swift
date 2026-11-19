import AppKit
import Carbon.HIToolbox

enum PromptSelectionKeyAction: Equatable {
    case copy
    case cut
    case delete
    case replace
    case moveToStart
    case moveToEnd
    case selectAllTerminalText
    case dismiss
    case passThrough

    init(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])
        if modifiers == .command, let commandAction = Self.commandAction(event) {
            self = commandAction
            return
        }
        switch Int(event.keyCode) {
        case kVK_Delete where [[], .shift, .option, .command].contains(modifiers):
            self = .delete
        case kVK_ForwardDelete where modifiers.isEmpty:
            self = .delete
        case kVK_LeftArrow where modifiers.isEmpty:
            self = .moveToStart
        case kVK_RightArrow where modifiers.isEmpty:
            self = .moveToEnd
        case kVK_Escape where modifiers.isEmpty:
            self = .dismiss
        default:
            self = modifiers.isSubset(of: .shift) && Self.typesText(event) ? .replace : .passThrough
        }
    }

    static func isSelectAll(_ event: NSEvent) -> Bool {
        event.type == .keyDown
            && event.modifierFlags.intersection([.shift, .control, .option, .command]) == .command
            && event.charactersIgnoringModifiers?.lowercased() == "a"
    }

    private static func commandAction(_ event: NSEvent) -> Self? {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c": .copy
        case "x": .cut
        case "v": .replace
        case "a": .selectAllTerminalText
        default: nil
        }
    }

    /// A key that types visible text or a space, not a control character or a function key's private-use character.
    private static func typesText(_ event: NSEvent) -> Bool {
        guard let characters = event.characters, !characters.isEmpty else { return false }
        return characters.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
        }
    }
}
