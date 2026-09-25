import SwiftUI

/// Right-click menu for a sidebar row that is part of a multi-selection.
struct SelectedSessionsContextMenu: View {
    @ObservedObject var store: ConversationStore
    let selectedConversations: [Conversation]
    let onDelete: () -> Void
    let onClear: () -> Void

    var body: some View {
        let resumableCount = selectedConversations.filter { store.canLaunch($0, action: .resume) }.count
        let branchableCount = selectedConversations.filter { store.canLaunch($0, action: .branch) }.count

        Button("Resume \(sessionCountLabel(resumableCount))", systemImage: "play") {
            store.launch(selectedConversations, action: .resume)
        }
        .disabled(resumableCount == 0)
        Button("Branch \(sessionCountLabel(branchableCount))", systemImage: "arrow.triangle.branch") {
            store.launch(selectedConversations, action: .branch)
        }
        .disabled(branchableCount == 0)
        Divider()
        Button("Delete \(sessionCountLabel(selectedConversations.count))…", systemImage: "trash", role: .destructive, action: onDelete)
            .disabled(store.isScanningThisMac || store.isDeletingSessions)
        Button("Clear selection", systemImage: "xmark.circle", action: onClear)
    }

    private func sessionCountLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "session" : "sessions")"
    }
}
