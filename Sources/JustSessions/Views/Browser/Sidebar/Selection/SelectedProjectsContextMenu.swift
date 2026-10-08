import SwiftUI

struct SelectedProjectsContextMenu: View {
    @ObservedObject var store: ConversationStore
    let selectedProjectIDs: Set<String>
    let onRemove: () -> Void
    let onRemoveAndDeleteSessions: () -> Void

    var body: some View {
        let deletableSessionCount = store.deletionPlan(forProjects: selectedProjectIDs).deletableConversations.count

        Text("\(selectedProjectIDs.count) projects selected")
        Button("Archive \(selectedProjectIDs.count) projects", systemImage: "archivebox", action: onRemove)
        Divider()
        Button(
            "Archive \(selectedProjectIDs.count) projects and delete all sessions (\(deletableSessionCount))…",
            systemImage: "trash",
            role: .destructive,
            action: onRemoveAndDeleteSessions
        )
        .disabled(deletableSessionCount == 0)
    }
}
