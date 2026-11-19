import SwiftUI

struct SessionManagementMenuItems: View {
    let store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)
        let isArchived = store.archivedSessions.isArchived(conversationID: conversation.id)

        if !conversation.isSubagent {
            Button("Rename", systemImage: "pencil", action: onRename)
            Button(isPinned ? "Unpin session" : "Pin session", systemImage: isPinned ? "pin.slash" : "pin") {
                store.setPinned(!isPinned, conversation: conversation)
            }
            Button(isArchived ? "Unarchive session" : "Archive session", systemImage: isArchived ? "tray.and.arrow.up" : "archivebox") {
                store.setArchived(!isArchived, conversations: [conversation])
            }
            SessionMoveToFolderMenu(store: store, conversation: conversation)
            Divider()
        }
        ConversationSharingMenuItems(selections: [
            ConversationExportSelection(conversation: conversation, title: store.title(for: conversation))
        ])
        Button("Copy session ID", systemImage: "doc.on.doc") {
            SessionLocationActions.copySessionID(conversation)
        }
        if conversation.host == .thisMac {
            Button("Reveal session file in Finder", systemImage: "doc.text.magnifyingglass") {
                SessionLocationActions.revealSessionFile(conversation)
            }
        }
        if !conversation.isSubagent {
            Divider()
            let endsCLIFirst = store.cliEndingBeforeDeletion(of: conversation) != nil
            Button(
                endsCLIFirst ? "Close and delete session…" : "Delete session…", systemImage: "trash", role: .destructive, action: onDelete
            )
            .disabled(store.isDeletionPending(for: conversation))
        }
    }
}
