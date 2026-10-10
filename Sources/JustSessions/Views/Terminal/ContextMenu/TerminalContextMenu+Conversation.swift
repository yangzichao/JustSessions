import AppKit

/// Renaming the tab's session and copying or exporting its conversation, as the tab's menu in the tab bar offers them.
extension TerminalContextMenu {
    /// Rename, then, once the tab knows its session, the conversation's sharing items, each group followed by a
    /// separator, as in the tab bar.
    var conversationItems: [NSMenuItem] {
        let renameItem = ActionMenuItem(title: localized("Rename"), systemImage: "pencil", isEnabled: tab.conversation != nil) {
            if let conversation = tab.conversation { onRename(conversation) }
        }
        guard let conversation = tab.conversation else { return [renameItem] }
        return [renameItem, .separator()] + sharingItems(for: conversation) + [.separator()]
    }

    private func sharingItems(for conversation: Conversation) -> [NSMenuItem] {
        let sharingController = ConversationSharingController.shared
        let selections = [ConversationExportSelection(conversation: conversation, title: tab.displayTitle)]
        let canShare = !sharingController.isSharing

        let copyItem = ActionMenuItem(title: localized("Copy conversation"), systemImage: "doc.on.doc", isEnabled: canShare) {
            sharingController.copy(selections)
        }
        copyItem.toolTip = localized("Copy saved messages and tool-call summaries as Markdown")

        let exportItem = submenuItem(title: localized("Export conversation"), systemImage: "square.and.arrow.up", items: [
            ActionMenuItem(title: localized("Markdown (.md)…")) { sharingController.export(selections, format: .markdown) },
            ActionMenuItem(title: localized("Plain text (.txt)…")) { sharingController.export(selections, format: .plainText) },
        ])
        exportItem.isEnabled = canShare
        exportItem.toolTip = localized("Save messages and tool-call summaries to a file")

        return [copyItem, exportItem]
    }
}
