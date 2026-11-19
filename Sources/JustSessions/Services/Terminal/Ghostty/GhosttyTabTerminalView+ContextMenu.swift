import AppKit

extension GhosttyTabTerminalView {
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let makeContextMenu else { return super.menu(for: event) }
        onFocus?()
        window?.makeFirstResponder(self)
        return makeContextMenu(link(under: event))
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

    override func rightMouseUp(with event: NSEvent) {
        guard makeContextMenu == nil else { return }
        super.rightMouseUp(with: event)
    }

    var selectionActive: Bool { terminalSurface?.hasSelection() == true }

    func copy(_ sender: Any) {
        copy(sender as Any?)
    }

    func paste(_ sender: Any) {
        promptSelection.deleteSelectedPromptForPaste()
        paste(sender as Any?)
    }
}
