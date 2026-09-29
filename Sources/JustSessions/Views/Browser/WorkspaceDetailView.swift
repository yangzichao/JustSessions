import SwiftUI

/// Right side of the window: the tab bar while tabs are open, above the selected tab's terminal or, with no tab
/// selected, the selected session's preview. Every tab's terminal stays in the view tree; only the selected one shows.
struct WorkspaceDetailView: View {
    @ObservedObject var store: ConversationStore
    let sessionSelection: SessionMultiSelection
    let onRename: (Conversation) -> Void
    let onDelete: (Conversation) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if !store.terminalSessions.isEmpty {
                WorkspaceTabBar(store: store, onRenameConversation: onRename)
                ThemeDivider()
            }
            ZStack {
                SessionPreviewPane(
                    store: store,
                    sessionSelection: sessionSelection,
                    onRename: onRename,
                    onDelete: onDelete
                )
                .shown(store.selectedTerminalID == nil)

                ForEach(store.terminalSessions) { session in
                    let isActive = store.selectedTerminalID == session.id
                    TerminalWorkspaceView(
                        session: session,
                        projectDisplayName: store.projectDisplayName(forProjectPath: session.projectDirectoryKey),
                        hostDisplayName: store.hasRemoteHosts ? session.host.displayName : nil,
                        isActive: isActive,
                        onReconnect: session.host == .thisMac ? nil : { store.reconnectRemoteTerminal(session.id) }
                    )
                    .shown(isActive)
                }
            }
        }
    }
}

private extension View {
    /// Hides the view from sight, clicks, and VoiceOver while leaving it in the view tree.
    func shown(_ isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}
