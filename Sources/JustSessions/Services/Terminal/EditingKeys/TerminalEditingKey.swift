import AppKit
import Carbon.HIToolbox

/// ⌘←, ⌘→, ⌘Delete, and ⌘Z, which a terminal sends as the control keys a shell or a CLI such as Claude Code reads as the
/// same edits, as iTerm2's Natural Text Editing does: Ctrl-A and Ctrl-E go to the start and end of the line, Ctrl-U
/// deletes back to its start, and Ctrl-_ undoes the last edit.
enum TerminalEditingKey: CaseIterable {
    case moveToLineStart
    case moveToLineEnd
    case deleteToLineStart
    case undo

    /// The key pressed with Command and no other modifier. Z is whichever key types `z` on the keyboard's layout, as
    /// for Edit → Undo; the arrows and Delete are the same keys on every layout.
    init?(_ event: NSEvent) {
        guard event.type == .keyDown,
            event.modifierFlags.intersection([.shift, .control, .option, .command]) == .command
        else { return nil }
        switch Int(event.keyCode) {
        case kVK_LeftArrow: self = .moveToLineStart
        case kVK_RightArrow: self = .moveToLineEnd
        case kVK_Delete: self = .deleteToLineStart
        default:
            guard event.charactersIgnoringModifiers?.lowercased() == "z" else { return nil }
            self = .undo
        }
    }

    var controlCharacter: String {
        switch self {
        case .moveToLineStart: "\u{01}"
        case .moveToLineEnd: "\u{05}"
        case .deleteToLineStart: "\u{15}"
        case .undo: "\u{1F}"
        }
    }

    var ghosttyTrigger: String {
        switch self {
        case .moveToLineStart: "super+arrow_left"
        case .moveToLineEnd: "super+arrow_right"
        case .deleteToLineStart: "super+backspace"
        case .undo: "super+z"
        }
    }
}
