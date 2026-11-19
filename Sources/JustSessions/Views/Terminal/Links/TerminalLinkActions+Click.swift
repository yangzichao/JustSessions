import AppKit

extension TerminalLinkActions {
    func openClicked(_ link: String) {
        let opener = tab.linkOpener
        guard let target = opener.target(of: link) else { return }
        guard case .localItem(let item) = target, item.kind == .file else {
            opener.open(target)
            return
        }
        switch fileLinkClickSettingsStore.choice {
        case .defaultApp:
            opener.open(target)
        case .askEachTime:
            popUpMenu(ActionMenu.make(items: menuItems(for: target)), tab.terminalView)
        case .editor(let name):
            if FileLinkEditorScope.includes(item.url),
                let editor = editorStore.editors(opening: .thisMac).first(where: { $0.name == name })
            {
                open(item, in: editor)
            } else {
                opener.open(target)
            }
        }
    }

    /// Both engines hand over a ⌘-clicked link while handling the click, Ghostty from within its own code, so the menu,
    /// which waits for a choice, shows once that is done.
    static func popUpAtPointer(_ menu: NSMenu, in view: NSView) {
        DispatchQueue.main.async { [weak view] in
            guard let view, let window = view.window else { return }
            let pointer = view.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            menu.popUp(positioning: nil, at: pointer, in: view)
        }
    }
}
