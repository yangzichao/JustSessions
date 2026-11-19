import AppKit

extension TerminalContextMenu {
    var closingItems: [NSMenuItem] {
        if store.deletesSessionWhenClosed(tab) {
            return [
                ActionMenuItem(title: localized("Keep session"), systemImage: "tray.and.arrow.down") {
                    store.keepSessionAfterClosing(tab)
                },
                ActionMenuItem(title: localized("Close and delete session"), systemImage: "trash") {
                    onCloseTab(tab.id)
                },
            ]
        }
        let closeTitle = tab.isPlainTerminal ? localized("Close terminal…") : localized("Close Tab…")
        var items: [NSMenuItem] = [ActionMenuItem(title: closeTitle, systemImage: "xmark") { onCloseTab(tab.id) }]
        if tab.closingNeed.hasRunningCLI {
            items.append(
                ActionMenuItem(title: localized("Close and end session"), systemImage: "stop.circle") {
                    store.closeTerminalEndingSession(tab.id)
                })
        }
        if let conversation = tab.conversation {
            items.append(
                ActionMenuItem(
                    title: localized("Close and delete session…"),
                    systemImage: "trash",
                    isEnabled: !store.isDeletionPending(for: conversation)
                ) {
                    onDelete(conversation)
                })
        }
        return items
    }
}
