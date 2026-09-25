import AppKit
import Carbon.HIToolbox

/// Shift-Return, and how a tab sends it to a CLI running in tmux: CSI u with Return's code (13) and Shift (2),
/// which tmux passes on and Claude Code reads as Shift-Return.
enum ShiftReturnKey {
    static let csiUSequence = "\u{1b}[13;2u"

    /// Return or the keypad's Enter, with Shift and no other modifier.
    static func matches(_ event: NSEvent) -> Bool {
        let returnKeyCodes: Set<UInt16> = [UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter)]
        return event.type == .keyDown
            && returnKeyCodes.contains(event.keyCode)
            && event.modifierFlags.intersection([.shift, .control, .option, .command]) == .shift
    }
}
