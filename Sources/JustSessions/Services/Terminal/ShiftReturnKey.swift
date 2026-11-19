import AppKit
import Carbon.HIToolbox

/// Shift-Return, and how a tab sends it to a CLI running in tmux, on this Mac or an SSH host: CSI u with Return's code
/// (13) and Shift (2), which tmux passes on to a CLI that asks for modifyOtherKeys, and Claude Code, Codex, Pi, and
/// OpenCode read as Shift-Return, adding a line to the prompt. See `ThisMacTmuxServer.globalOptions` and
/// `RemoteCLICommandBuilder` for what tmux needs to pass it on.
enum ShiftReturnKey {
    static let csiUSequence = "\u{1b}[13;2u"

    static func matches(_ event: NSEvent) -> Bool {
        let returnKeyCodes: Set<UInt16> = [UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter)]
        return event.type == .keyDown
            && returnKeyCodes.contains(event.keyCode)
            && event.modifierFlags.intersection([.shift, .control, .option, .command]) == .shift
    }
}
