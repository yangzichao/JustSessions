import SwiftUI

struct SingleSessionContextMenu: View {
    let store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let openTab = store.runningTerminal(for: conversation)
        let otherWindowTab = openTab == nil ? store.runningTerminalInAnotherWindow(for: conversation) : nil
        if otherWindowTab != nil {
            Button("Show in Other Window", systemImage: "macwindow") {
                store.showRunningTerminalInAnotherWindow(for: conversation)
            }
            if store.canMoveTerminalHere(for: conversation) {
                Button("Move Tab to This Window", systemImage: "macwindow.badge.plus") {
                    store.moveTerminalHere(for: conversation)
                }
            }
        } else if openTab == nil {
            Button("Resume", systemImage: "play") {
                store.resume(conversation)
            }
            .disabled(!store.canLaunch(conversation, action: .resume))
        }
        if conversation.provider.supportsBranchFromLauncher {
            Button("Branch", systemImage: "arrow.triangle.branch") {
                store.launch(conversation, action: .branch)
            }
            .disabled(!store.canLaunch(conversation, action: .branch))
        }
        SessionSplitMenuItems(store: store, conversation: conversation)
        if store.canEndSession(conversation) {
            Button("End session", systemImage: "stop.circle", role: .destructive) {
                store.endSession(conversation)
            }
        }
        Divider()
        SessionManagementMenuItems(store: store, conversation: conversation, onRename: onRename, onDelete: onDelete)
    }
}
