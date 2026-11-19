import AppKit

/// SwiftTerm would send ⌘← and ⌘→ as a word back and forward, and nothing for ⌘Delete, and Edit → Undo would take ⌘Z.
/// AppKit offers a key with Command or Control to every view in the window before the menus, so only the terminal with
/// the keyboard takes it. While an input method composes text, the key belongs to it.
extension SelectableTerminalView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self, !hasMarkedText() else { return super.performKeyEquivalent(with: event) }
        if PromptSelectionKeyAction.isSelectAll(event), promptSelection.selectPrompt() {
            return true
        }
        if let editingKey = TerminalEditingKey(event) {
            send(txt: editingKey.controlCharacter)
            return true
        }
        guard let controlKeyBytes = bytesToSend(forControlKey: event) else { return super.performKeyEquivalent(with: event) }
        send(txt: controlKeyBytes)
        return true
    }
}
