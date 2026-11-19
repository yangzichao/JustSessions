import AppKit

extension TranscriptTextView {
    /// AppKit builds a new menu on every call.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard let entryID = selectionKey?.entryIndex,
            let items = TranscriptBookmarkTargetRegistry.shared.target(for: self)?.contextMenuItems(entryID), !items.isEmpty
        else { return menu }
        for (offset, item) in (items + [NSMenuItem.separator()]).enumerated() { menu.insertItem(item, at: offset) }
        return menu
    }
}
