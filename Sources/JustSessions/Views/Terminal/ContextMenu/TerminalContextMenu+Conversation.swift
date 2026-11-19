import AppKit

/// Renaming the tab's session, then copying, exporting, or finding it, as the tab's menu in the tab bar offers them;
/// see `TerminalTabMenuItems`.
extension TerminalContextMenu {
    /// Rename, then, once the tab knows its session, the session's other items, each group followed by a separator, as
    /// in the tab bar.
    var conversationItems: [NSMenuItem] {
        let renameItem = ActionMenuItem(title: localized("Rename"), systemImage: "pencil", isEnabled: tab.conversation != nil) {
            if let conversation = store.conversationToRename(fromTab: tab) { onRename(conversation) }
        }
        guard let conversation = tab.conversation else { return [renameItem, .separator()] }
        return [renameItem, .separator()]
            + sharingItems(for: conversation)
            + locationItems(for: conversation)
            + [.separator()]
    }

    /// Reveal is only for a session on this Mac, whose file the Finder can show.
    private func locationItems(for conversation: Conversation) -> [NSMenuItem] {
        let copyIDItem = ActionMenuItem(title: localized("Copy session ID"), systemImage: "doc.on.doc") {
            SessionLocationActions.copySessionID(conversation)
        }
        guard conversation.host == .thisMac else { return [copyIDItem] }
        let revealItem = ActionMenuItem(title: localized("Reveal session file in Finder"), systemImage: "doc.text.magnifyingglass") {
            SessionLocationActions.revealSessionFile(conversation)
        }
        return [copyIDItem, revealItem]
    }

    private func sharingItems(for conversation: Conversation) -> [NSMenuItem] {
        let sharingController = ConversationSharingController.shared
        let selections = [ConversationExportSelection(conversation: conversation, title: tab.displayTitle)]
        let canShare = !sharingController.isSharing

        let copyItem = ActionMenuItem(title: localized("Copy conversation"), systemImage: "doc.on.doc", isEnabled: canShare) {
            sharingController.copy(selections)
        }
        copyItem.toolTip = localized("Copy saved messages and tool-call summaries as Markdown")

        let exportItem = submenuItem(
            title: localized("Export conversation"), systemImage: "square.and.arrow.up",
            items: [
                ActionMenuItem(title: localized("Markdown (.md)…")) { sharingController.export(selections, format: .markdown) },
                ActionMenuItem(title: localized("Plain text (.txt)…")) { sharingController.export(selections, format: .plainText) },
            ])
        exportItem.isEnabled = canShare
        exportItem.toolTip = localized("Save messages and tool-call summaries to a file")

        return [copyItem, exportItem]
    }
}
