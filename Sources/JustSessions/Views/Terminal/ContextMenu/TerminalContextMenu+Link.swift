import AppKit

extension TerminalContextMenu {
    var linkItems: [NSMenuItem] {
        guard let linkUnderPointer else { return [] }
        return TerminalLinkActions(store: store, tab: tab, language: language, editorStore: editorStore)
            .menuItems(for: linkUnderPointer)
    }
}
