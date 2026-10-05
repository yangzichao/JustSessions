import SwiftUI

/// Right-click menu for a sidebar session row that is not part of a multi-selection.
struct SingleSessionContextMenu: View {
    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void
    /// Asks what to do with the tab's CLI, as the tab's own close button does.
    let onCloseTab: (UUID) -> Void

    var body: some View {
        // Resuming a session a tab already runs would only show that tab, which clicking the row does; closing it is
        // what is left to do from here.
        let openTab = store.runningTerminal(for: conversation)
        if let openTab {
            Button("Close terminal…", systemImage: "xmark", role: .destructive) {
                onCloseTab(openTab.id)
            }
        } else {
            Button("Resume", systemImage: "play") {
                store.launch(conversation, action: .resume)
            }
            .disabled(!store.canLaunch(conversation, action: .resume))
        }
        if conversation.provider.supportsBranchFromLauncher {
            Button("Branch", systemImage: "arrow.triangle.branch") {
                store.launch(conversation, action: .branch)
            }
            .disabled(!store.canLaunch(conversation, action: .branch))
        }
        // An open tab's close already offers to end its CLI.
        if openTab == nil && store.isRunningInTmux(conversation) {
            Button("End on \(conversation.host.nameInSentence)", systemImage: "stop.circle") {
                store.endTmuxSession(for: conversation)
            }
        }
        Divider()
        SessionManagementMenuItems(store: store, conversation: conversation, onRename: onRename, onDelete: onDelete)
    }
}
