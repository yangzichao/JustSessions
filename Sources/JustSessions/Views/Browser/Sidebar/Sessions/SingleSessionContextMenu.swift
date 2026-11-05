import SwiftUI

/// Right-click menu for a sidebar session row that is not part of a multi-selection. The row stands for the session,
/// not its tab, so it offers Resume while nothing runs the session and End session while its CLI runs, wherever that
/// is. End session doesn't ask first: choosing it from the row's menu is already deliberate, and the session can be
/// resumed. Closing the tab alone, which can keep the CLI running, is left to the tab and Open tabs.
struct SingleSessionContextMenu: View {
    let store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        // Resuming a session a tab already runs would only show that tab, which clicking the row does.
        let openTab = store.runningTerminal(for: conversation)
        // A session runs in one tab across the app's windows; another window's tab is shown there, not opened here.
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
