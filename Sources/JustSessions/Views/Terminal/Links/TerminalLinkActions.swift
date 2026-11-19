import AppKit

@MainActor
struct TerminalLinkActions {
    let store: ConversationStore
    let tab: TerminalSession
    var language: AppInterfaceLanguage? = nil
    var editorStore: ExternalEditorStore = .shared
    var fileLinkClickSettingsStore: FileLinkClickSettingsStore = .shared
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
