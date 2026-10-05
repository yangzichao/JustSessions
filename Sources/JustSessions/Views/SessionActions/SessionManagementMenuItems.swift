import SwiftUI

/// Rename, pin, copy, reveal, and delete for one session, in its sidebar row's menu and the preview's More menu.
struct SessionManagementMenuItems: View {
    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)

        Button("Rename", systemImage: "pencil", action: onRename)
        Button(isPinned ? "Unpin session" : "Pin session", systemImage: isPinned ? "pin.slash" : "pin") {
            store.setPinned(!isPinned, conversation: conversation)
        }
        Divider()
        ConversationSharingMenuItems(selections: [ConversationExportSelection(conversation: conversation, title: store.title(for: conversation))])
        Button("Copy session ID", systemImage: "doc.on.doc") {
            SessionLocationActions.copySessionID(conversation)
        }
        if conversation.host == .thisMac {
            Button("Reveal session file in Finder", systemImage: "doc.text.magnifyingglass") {
                SessionLocationActions.revealSessionFile(conversation)
            }
        }
        Divider()
        Button("Delete session…", systemImage: "trash", role: .destructive, action: onDelete)
            .disabled(store.hasTerminal(for: conversation) || store.isDeletionPending(for: conversation))
    }
}
