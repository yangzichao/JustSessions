import SwiftUI

/// Right-click menu for a sidebar session row that is not part of a multi-selection.
struct SingleSessionContextMenu: View {
    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)

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
        if store.isRunningInRemoteTmux(conversation) {
            Button("End on \(conversation.remoteHost ?? "host")", systemImage: "stop.circle") {
                store.endRemoteTmuxSession(for: conversation)
            }
        }
        Divider()
        Button("Rename", systemImage: "pencil", action: onRename)
        Button(isPinned ? "Unpin session" : "Pin session", systemImage: isPinned ? "pin.slash" : "pin") {
            store.setPinned(!isPinned, conversation: conversation)
        }
        Button("Copy session ID", systemImage: "doc.on.doc") {
            SessionLocationActions.copySessionID(conversation)
        }
        if !conversation.isRemote {
            Button("Reveal session file in Finder", systemImage: "doc.text.magnifyingglass") {
                SessionLocationActions.revealSessionFile(conversation)
            }
        }
        if conversation.supportsDeletionFromLauncher {
            Divider()
            Button("Delete session…", systemImage: "trash", role: .destructive, action: onDelete)
                .disabled(store.hasTerminal(for: conversation) || store.isLoading || store.isDeletingSessions)
        }
    }
}
