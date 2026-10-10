import AppKit

/// What a right-click in a tab's terminal offers: copying, pasting, and selecting its text, as a terminal app's menu
/// does, then what the tab's menu in the tab bar offers, in the same order. It leaves out New session, which is about
/// the tab's project rather than its terminal. AppKit asks for the menu on each right-click, so it is built each time,
/// from the terminal's selection, the tab's split, and the language chosen in Settings as they are then.
@MainActor
struct TerminalContextMenu {
    let store: ConversationStore
    let tab: TerminalSession
    let onRename: (Conversation) -> Void
    /// Asks what to do with the tab's CLI, as the tab's × does.
    let onCloseTab: (UUID) -> Void
    /// The language chosen in Settings when nil.
    var language: AppInterfaceLanguage? = nil

    func makeMenu() -> NSMenu {
        makeMenu(items: textEditingItems + [.separator()] + tabItems)
    }

    /// Copy needs a selection. Paste needs text on the clipboard, the only kind SwiftTerm pastes.
    private var textEditingItems: [NSMenuItem] {
        let terminalView = tab.terminalView
        return [
            ActionMenuItem(title: localized("Copy"), systemImage: "doc.on.doc", isEnabled: terminalView.selectionActive) {
                terminalView.copy(terminalView)
            },
            ActionMenuItem(
                title: localized("Paste"),
                systemImage: "doc.on.clipboard",
                isEnabled: NSPasteboard.general.availableType(from: [.string]) != nil
            ) {
                terminalView.paste(terminalView)
            },
            ActionMenuItem(title: localized("Select All"), systemImage: "selection.pin.in.out") {
                terminalView.selectAll(terminalView)
            },
        ]
    }

    /// As the tab's menu in the tab bar has them after New session.
    private var tabItems: [NSMenuItem] {
        let closeTitle = tab.isPlainTerminal ? localized("Close terminal…") : localized("End session…")
        let closeItem = ActionMenuItem(title: closeTitle, systemImage: "xmark") { onCloseTab(tab.id) }
        if tab.isPlainTerminal { return splitItems + [closeItem] }
        return conversationItems + splitItems + [closeItem]
    }

    func localized(_ value: String.LocalizationValue) -> String {
        AppLocalization.string(value, language: language)
    }

    /// A menu whose items are enabled or not as they were built. AppKit's own check would turn every item on, since
    /// each one can always run its action.
    func makeMenu(title: String = "", items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        menu.items = items
        return menu
    }

    func submenuItem(title: String, systemImage: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        item.submenu = makeMenu(title: title, items: items)
        return item
    }
}
