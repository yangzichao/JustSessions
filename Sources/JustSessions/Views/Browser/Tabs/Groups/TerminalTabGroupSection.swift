import SwiftUI

/// One project's tabs behind its group label, underlined in the group color. A collapsed group shows only its label.
struct TerminalTabGroupSection: View {
    @ObservedObject var store: ConversationStore
    let group: TerminalTabGroup<TerminalSession>
    let color: ThemeColor
    let isCollapsed: Bool
    let onToggleCollapsed: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void
    let onTabDragChanged: (UUID, CGPoint) -> Void
    let onTabDragEnded: (UUID, CGPoint) -> Void

    /// What the hidden tabs' CLIs are doing. A plain terminal runs no session, so it does not count.
    private func hiddenTabsActivity(_ hiddenTabs: [TerminalSession]) -> SessionActivitySummary {
        SessionActivitySummary(activities: hiddenTabs.filter { !$0.isPlainTerminal && $0.isRunning }.map(\.cliActivity))
    }

    var body: some View {
        let hiddenTabs = isCollapsed ? group.tabs : []
        HStack(spacing: 6) {
            TerminalTabGroupLabel(
                projectName: store.projectDisplayName(forProjectPath: group.projectDirectoryKey),
                location: ProjectLocation(key: group.projectDirectoryKey),
                color: color,
                tabCount: group.tabs.count,
                isCollapsed: isCollapsed,
                hiddenTabCount: hiddenTabs.count,
                hiddenTabsActivity: hiddenTabsActivity(hiddenTabs),
                onToggleCollapsed: onToggleCollapsed
            )
            ForEach(isCollapsed ? [] : group.tabs) { session in
                TerminalTab(
                    session: session,
                    isSelected: store.selectedTerminalID == session.id,
                    isDocked: store.paneLayout.contains(.terminal(session.id)),
                    canSplit: store.focusedPaneContent != .terminal(session.id),
                    onSelect: { store.selectTerminal(session.id) },
                    onRename: onRenameConversation,
                    onSplit: { downward in
                        store.dockPane(.terminal(session.id), on: downward ? .bottom : .trailing, of: store.focusedPaneContent)
                    },
                    onClosePane: { store.closePane(.terminal(session.id)) },
                    onClose: { onCloseTab(session.id) },
                    onDragChanged: { onTabDragChanged(session.id, $0) },
                    onDragEnded: { onTabDragEnded(session.id, $0) }
                )
                .id(session.id)
            }
        }
        .padding(.bottom, 3)
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(color.opacity(0.8))
                .frame(height: 2)
        }
    }
}
