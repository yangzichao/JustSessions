import SwiftUI

struct TerminalTabMenuItems: View {
    let store: ConversationStore
    @ObservedObject var tab: TerminalSession
    let onRename: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void
    let onDelete: (Conversation) -> Void

    var body: some View {
        if !tab.isPlainTerminal {
            sessionItems
            Divider()
        }
        TerminalTabSplitMenuItems(splitMenu: store.splitMenu(forTab: tab.id)) { action in
            store.performSplitAction(action, fromTab: tab.id, closeTab: onCloseTab)
        }
        if store.deletesSessionWhenClosed(tab) {
            closingDeletingSessionItems
        } else {
            Button(tab.isPlainTerminal ? "Close terminal…" : "Close Tab…", systemImage: "xmark", role: .destructive) {
                onCloseTab(tab.id)
            }
            closingWithSessionItems
        }
    }

    @ViewBuilder private var closingDeletingSessionItems: some View {
        Button("Keep session", systemImage: "tray.and.arrow.down") {
            store.keepSessionAfterClosing(tab)
        }
        Button("Close and delete session", systemImage: "trash", role: .destructive) {
            onCloseTab(tab.id)
        }
    }

    @ViewBuilder private var sessionItems: some View {
        Button("Rename", systemImage: "pencil") {
            if let conversation = store.conversationToRename(fromTab: tab) { onRename(conversation) }
        }
        .disabled(tab.conversation == nil)
        if let conversation = tab.conversation {
            Divider()
            ConversationSharingMenuItems(selections: [ConversationExportSelection(conversation: conversation, title: tab.displayTitle)])
            Button("Copy session ID", systemImage: "doc.on.doc") {
                SessionLocationActions.copySessionID(conversation)
            }
            if conversation.host == .thisMac {
                Button("Reveal session file in Finder", systemImage: "doc.text.magnifyingglass") {
                    SessionLocationActions.revealSessionFile(conversation)
                }
            }
        }
    }

    @ViewBuilder private var closingWithSessionItems: some View {
        if tab.closingNeed.hasRunningCLI {
            Button("Close and end session", systemImage: "stop.circle", role: .destructive) {
                store.closeTerminalEndingSession(tab.id)
            }
        }
        if let conversation = tab.conversation {
            Button("Close and delete session…", systemImage: "trash", role: .destructive) {
                onDelete(conversation)
            }
            .disabled(store.isDeletionPending(for: conversation))
        }
    }
}
