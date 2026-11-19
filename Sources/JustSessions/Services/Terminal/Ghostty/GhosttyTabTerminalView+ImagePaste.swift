import AppKit

/// ⌘V and both menus' Paste with only an image on the clipboard; see `TerminalImagePaste`. Ghostty pastes only text and
/// drops an empty paste, so for a CLI on this Mac the tab sends the empty paste itself, as a SwiftTerm tab's paste does.
extension GhosttyTabTerminalView {
    override func paste(_ sender: Any?) {
        guard !pastesClipboardImage() else { return }
        super.paste(sender)
    }

    func pastesClipboardImage() -> Bool {
        switch imagePaste.handleClipboardImage() {
        case nil:
            return false
        case .sendNothing:
            return true
        case .sendEmptyPaste:
            if isBracketedPasteOn { sendAsTyped(Self.emptyBracketedPaste) }
            return true
        }
    }

    private static let emptyBracketedPaste = String(
        decoding: TerminalFileDropPaste.bracketedPasteStart + TerminalFileDropPaste.bracketedPasteEnd,
        as: UTF8.self
    )
}
