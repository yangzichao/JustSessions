import AppKit

/// A right-click on a Ghostty terminal shows the app's menu, as on a SwiftTerm one; see `TerminalContextMenu`. Ghostty's
/// own menu, which offers only Copy and only over a selection, never shows while the app gives the terminal a menu.
extension GhosttyTabTerminalView {
    /// See `SelectableTerminalView.menu(for:)`: the terminal takes the keyboard first, so what the menu pastes and what
    /// is typed next both go to it.
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let makeContextMenu else { return super.menu(for: event) }
        onFocus?()
        window?.makeFirstResponder(self)
        return makeContextMenu()
    }

    /// Ghostty's own right-click never asks for the menu: it hands the click to Ghostty, which passes it on to a
    /// program that reads the mouse, or shows Ghostty's menu over a selection. With the app's menu, the right-click
    /// shows that menu, as `NSView`'s does, and the program gets nothing, as in a SwiftTerm tab.
    override func rightMouseDown(with event: NSEvent) {
        guard makeContextMenu != nil, let menu = menu(for: event) else {
            super.rightMouseDown(with: event)
            return
        }
        popUpContextMenu(menu, event, self)
    }

    /// The release of a right-click that showed the app's menu doesn't go to Ghostty either.
    override func rightMouseUp(with event: NSEvent) {
        guard makeContextMenu == nil else { return }
        super.rightMouseUp(with: event)
    }

    var selectionActive: Bool { terminalSurface?.hasSelection() == true }

    /// The menu's Copy, as the Edit menu's: Ghostty puts the selection on the general pasteboard.
    func copy(_ sender: Any) {
        super.copy(sender)
    }

    /// The menu's Paste, through the Edit menu's action, which `AppTerminalView` keeps to its own module.
    func paste(_ sender: Any) {
        NSApp.sendAction(#selector(NSText.paste(_:)), to: self, from: sender)
    }
}
