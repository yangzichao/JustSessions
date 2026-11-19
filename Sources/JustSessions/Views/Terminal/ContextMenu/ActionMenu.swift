import AppKit

@MainActor
enum ActionMenu {
    /// A menu whose items are enabled or not as they were built. AppKit's own check would turn every item on, since
    /// each one can always run its action.
    static func make(title: String = "", items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        menu.items = items
        return menu
    }

    static func submenuItem(title: String, systemImage: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        item.submenu = make(title: title, items: items)
        return item
    }
}
