import SwiftUI

/// Right side of the window: the tab bar while tabs are open, above the selected tab's terminal or, with no tab
/// selected, the selected session's preview. Every tab's terminal stays in the view tree; only the selected one shows.
/// The tab bar runs up into the title bar, level with the window buttons; with no tabs open, the title bar stays clear.
struct WorkspaceDetailView: View {
    @ObservedObject var store: ConversationStore
    let sessionSelection: SessionMultiSelection
    let isSidebarHidden: Bool
    let onRename: (Conversation) -> Void
    let onCloseTerminal: (UUID) -> Void
    let onDelete: (Conversation) -> Void

    @Environment(\.titleBarRow) private var titleBarRow

    var body: some View {
        VStack(spacing: 0) {
            if store.terminalSessions.isEmpty {
                Color.clear.frame(height: titleBarRow.height)
            } else {
                WorkspaceTabBar(
                    store: store,
                    titleBarHeight: titleBarRow.height,
                    // With the sidebar hidden, the bar's leading edge is the window's, under the window buttons.
                    leadingClearance: isSidebarHidden ? titleBarRow.toggleTrailingEdge : 0,
                    onRenameConversation: onRename,
                    onCloseTerminal: onCloseTerminal
                )
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
                        isActive: isActive,
                        onReconnect: session.host == .thisMac ? nil : { store.reconnectRemoteTerminal(session.id) }
                    )
                    .shown(isActive)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
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
