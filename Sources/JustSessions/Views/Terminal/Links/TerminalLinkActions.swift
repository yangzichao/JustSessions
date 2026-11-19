import AppKit

/// What can be done with a link in a tab's terminal, in the tab's window: the items a right-click on it shows, and what
/// a ⌘-click does (`TerminalLinkActions+Click`). `TerminalLinkOpener` says what the link points at and runs each one.
/// - A web page or an email address: Open Link, as ⌘-clicking does, and Copy Link.
/// - A file on this Mac: Open, unless opening it would run it; Open in, with the installed editors; Reveal in Finder;
///   Copy Path.
/// - A folder on this Mac: Open in Finder, Open in, and Copy Path.
/// - A path in a tab on an SSH host: Copy Path, since the file is on the host.
@MainActor
struct TerminalLinkActions {
    let store: ConversationStore
    let tab: TerminalSession
    /// The language chosen in Settings when nil.
    var language: AppInterfaceLanguage? = nil
    /// The editors a file or folder the link names can open in.
    var editorStore: ExternalEditorStore = .shared
    var fileLinkClickSettingsStore: FileLinkClickSettingsStore = .shared
    /// Shows the menu a ⌘-click on a file asks with, at the pointer; replaced in tests, since a shown menu waits for a
    /// choice.
    var popUpMenu: @MainActor (NSMenu, NSView) -> Void = TerminalLinkActions.popUpAtPointer

    func menuItems(for link: String) -> [NSMenuItem] {
        guard let target = tab.linkOpener.target(of: link) else { return [] }
        return menuItems(for: target)
    }

    func menuItems(for target: TerminalLinkTarget) -> [NSMenuItem] {
        let opener = tab.linkOpener
        switch target {
        case .webAddress(let url):
            return [
                ActionMenuItem(title: localized("Open Link"), systemImage: "arrow.up.forward.app") { opener.open(target) },
                ActionMenuItem(title: localized("Copy Link"), systemImage: "link") { opener.copyText(url.absoluteString) },
            ]
        case .localItem(let item):
            var items: [NSMenuItem] = []
            if opener.canOpen(target) {
                let openTitle = item.kind == .folder ? localized("Open in Finder") : localized("Open")
                items.append(ActionMenuItem(title: openTitle, systemImage: "arrow.up.forward.app") { opener.open(target) })
            }
            if let openInEditorItem = openInEditorItem(for: item) { items.append(openInEditorItem) }
            if item.kind == .file {
                items.append(
                    ActionMenuItem(title: localized("Reveal in Finder"), systemImage: "folder") {
                        opener.revealInFinder(item.url)
                    })
            }
            items.append(copyPathItem(item.url.path))
            return items
        case .remotePath(let path):
            return [copyPathItem(path)]
        }
    }

    /// Opens the file or folder in `editor`, and says so in the window when the editor can't.
    func open(_ item: TerminalLinkLocalItem, in editor: InstalledExternalEditor) {
        let opener = tab.linkOpener
        let store = store
        let itemName = item.url.lastPathComponent
        let language = language
        Task {
            do {
                try await opener.openInEditor(item, editor)
            } catch {
                store.showError(
                    AppLocalization.string(
                        "Could not open \(itemName) in \(editor.name): \(error.localizedDescription)",
                        language: language
                    ))
            }
        }
    }

    private func copyPathItem(_ path: String) -> NSMenuItem {
        ActionMenuItem(title: localized("Copy Path"), systemImage: "doc.on.doc") { [opener = tab.linkOpener] in
            opener.copyText(path)
        }
    }

    /// The installed editors, as "Open project in" lists them; none shows no item.
    private func openInEditorItem(for item: TerminalLinkLocalItem) -> NSMenuItem? {
        let editors = editorStore.editors(opening: .thisMac)
        guard !editors.isEmpty else { return nil }
        return ActionMenu.submenuItem(
            title: localized("Open in"),
            systemImage: "chevron.left.forwardslash.chevron.right",
            items: editors.map { editor in
                let editorItem = ActionMenuItem(title: editor.name) { open(item, in: editor) }
                editorItem.image = editor.icon
                return editorItem
            }
        )
    }

    private func localized(_ value: String.LocalizationValue) -> String {
        AppLocalization.string(value, language: language)
    }
}
