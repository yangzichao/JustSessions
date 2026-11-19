import SwiftUI

struct SelectedSessionsContextMenu: View {
    let store: ConversationStore
    let selectedConversations: [Conversation]
    let onDelete: () -> Void

    var body: some View {
        let resumableCount = selectedConversations.filter { store.canLaunch($0, action: .resume) }.count
        let branchableCount = selectedConversations.filter { store.canLaunch($0, action: .branch) }.count
        let endableCount = selectedConversations.filter(store.canEndSession).count
        let archivedCount = selectedConversations.filter { store.archivedSessions.isArchived(conversationID: $0.id) }.count

        Button("Resume \(resumableCount) sessions", systemImage: "play") {
            store.resume(selectedConversations)
        }
        .disabled(resumableCount == 0)
        Button("Branch \(branchableCount) sessions", systemImage: "arrow.triangle.branch") {
            store.launch(selectedConversations, action: .branch)
        }
        .disabled(branchableCount == 0)
        if endableCount > 0 {
            Button("End \(endableCount) sessions", systemImage: "stop.circle", role: .destructive) {
                store.endSessions(selectedConversations)
            }
        }
        Divider()
        if archivedCount < selectedConversations.count {
            Button("Archive \(selectedConversations.count - archivedCount) sessions", systemImage: "archivebox") {
                store.setArchived(true, conversations: selectedConversations)
            }
        }
        if archivedCount > 0 {
            Button("Unarchive \(archivedCount) sessions", systemImage: "tray.and.arrow.up") {
                store.setArchived(false, conversations: selectedConversations)
            }
        }
        Divider()
        ConversationSharingMenuItems(
            selections: selectedConversations.map {
                ConversationExportSelection(conversation: $0, title: store.title(for: $0))
            })
        Divider()
        Button("Delete \(selectedConversations.count) sessions…", systemImage: "trash", role: .destructive, action: onDelete)
            .disabled(selectedConversations.allSatisfy(store.isDeletionPending(for:)))
    }

}
