import SwiftUI

/// Right-click menu for a sidebar row that is part of a multi-selection.
struct SelectedSessionsContextMenu: View {
    @ObservedObject var store: ConversationStore
    let selectedConversations: [Conversation]
    let onDelete: () -> Void

    var body: some View {
        let resumableCount = selectedConversations.filter { store.canLaunch($0, action: .resume) }.count
        let branchableCount = selectedConversations.filter { store.canLaunch($0, action: .branch) }.count

        Button("Resume \(resumableCount) sessions", systemImage: "play") {
            store.launch(selectedConversations, action: .resume)
        }
        .disabled(resumableCount == 0)
        Button("Branch \(branchableCount) sessions", systemImage: "arrow.triangle.branch") {
            store.launch(selectedConversations, action: .branch)
        }
        .disabled(branchableCount == 0)
        Divider()
        ConversationSharingMenuItems(selections: selectedConversations.map {
            ConversationExportSelection(conversation: $0, title: store.title(for: $0))
        })
        Divider()
        Button("Delete \(selectedConversations.count) sessions…", systemImage: "trash", role: .destructive, action: onDelete)
            .disabled(!store.canStartDeletion(of: selectedConversations))
    }

}
