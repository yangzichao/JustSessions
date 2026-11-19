import AppKit

/// Closing the tab, as the tab's menu in the tab bar offers it; see `TerminalTabMenuItems`.
extension TerminalContextMenu {
    /// Close Tab… asks what to do with the CLI, as the tab's × does. Close and end session stops a running CLI without
    /// asking, and Close and delete session… asks before it deletes the tab's session. A session started with Delete
    /// the session when its tab closes offers Keep session, and Close and delete session, which doesn't ask.
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
