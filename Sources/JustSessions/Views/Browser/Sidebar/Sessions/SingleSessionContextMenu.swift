import SwiftUI

/// Right-click menu for a sidebar session row that is not part of a multi-selection.
struct SingleSessionContextMenu: View {
    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button("Resume", systemImage: "play") {
            store.launch(conversation, action: .resume)
        }
        .disabled(!store.canLaunch(conversation, action: .resume))
        if conversation.provider.supportsBranchFromLauncher {
            Button("Branch", systemImage: "arrow.triangle.branch") {
                store.launch(conversation, action: .branch)
            }
            .disabled(!store.canLaunch(conversation, action: .branch))
        }
        Button("Open preview in pane", systemImage: "rectangle.split.2x1") {
            store.dockPane(.preview(conversation.id), on: .trailing, of: store.focusedPaneContent)
        }
        if store.isRunningInTmux(conversation) {
            Button("End on \(conversation.host.nameInSentence)", systemImage: "stop.circle") {
                store.endTmuxSession(for: conversation)
            }
        }
        Divider()
        SessionManagementMenuItems(store: store, conversation: conversation, onRename: onRename, onDelete: onDelete)
    }
}
