import AppKit

@MainActor
struct TerminalContextMenu {
    let store: ConversationStore
    let tab: TerminalSession
    let onRename: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void
    let onDelete: (Conversation) -> Void
    var linkUnderPointer: String? = nil
    var language: AppInterfaceLanguage? = nil
    var editorStore: ExternalEditorStore = .shared

    func makeMenu() -> NSMenu {
        let linkItems = linkItems
        let linkSection = linkItems.isEmpty ? [] : linkItems + [.separator()]
        let menu = makeMenu(items: linkSection + textEditingItems + [.separator()] + tabItems)
        // macOS's context menu plug-ins would add AutoFill (Contact…, Passwords…, Credit Card…), as for any view that
        // takes typing. A terminal has no form to fill.
        menu.allowsContextMenuPlugIns = false
        return menu
    }

    private var textEditingItems: [NSMenuItem] {
        let terminalView = tab.terminalView
        let hasSelection = terminalView.selectionActive || terminalView.promptSelection.isActive
        return [
            ActionMenuItem(title: localized("Copy"), systemImage: "doc.on.doc", isEnabled: hasSelection) {
                terminalView.copy(terminalView)
            },
            ActionMenuItem(
                title: localized("Paste"),
                systemImage: "doc.on.clipboard",
                isEnabled: NSPasteboard.general.availableType(from: [.string]) != nil
                    || terminalView.imagePaste.clipboardHoldsOnlyAnImage
            ) {
                terminalView.paste(terminalView)
            },
            ActionMenuItem(title: localized("Select All"), systemImage: "selection.pin.in.out") {
                terminalView.promptSelection.cancel()
                terminalView.selectAll(terminalView)
            },
        ]
    }

    private var tabItems: [NSMenuItem] {
        if tab.isPlainTerminal { return splitItems + closingItems }
        return conversationItems + splitItems + closingItems
    }

    func localized(_ value: String.LocalizationValue) -> String {
        AppLocalization.string(value, language: language)
    }

    func makeMenu(title: String = "", items: [NSMenuItem]) -> NSMenu {
        ActionMenu.make(title: title, items: items)
    }

    func submenuItem(title: String, systemImage: String, items: [NSMenuItem]) -> NSMenuItem {
        ActionMenu.submenuItem(title: title, systemImage: systemImage, items: items)
    }
}
