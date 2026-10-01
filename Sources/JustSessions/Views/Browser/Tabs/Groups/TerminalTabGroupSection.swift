import SwiftUI

/// One project's tabs behind its group label, underlined in the group color. A collapsed group keeps only its
/// selected tab in sight.
struct TerminalTabGroupSection: View {
    @ObservedObject var store: ConversationStore
    let group: TerminalTabGroup<TerminalSession>
    let color: ThemeColor
    let isCollapsed: Bool
    let onToggleCollapsed: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void

    private var visibleTabs: [TerminalSession] {
        isCollapsed ? group.tabs.filter { $0.id == store.selectedTerminalID } : group.tabs
    }

    private var hiddenTabs: [TerminalSession] {
        isCollapsed ? group.tabs.filter { $0.id != store.selectedTerminalID } : []
    }

    /// What the hidden tabs' CLIs are doing. A plain terminal runs no session, so it does not count.
    private func hiddenTabsActivity(_ hiddenTabs: [TerminalSession]) -> SessionActivitySummary {
        SessionActivitySummary(activities: hiddenTabs.filter { !$0.isPlainTerminal && !$0.hasExited }.map(\.cliActivity))
    }

    var body: some View {
        let hiddenTabs = hiddenTabs
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
            ForEach(visibleTabs) { session in
                TerminalTab(
                    session: session,
                    isSelected: store.selectedTerminalID == session.id,
                    onSelect: { store.selectTerminal(session.id) },
                    onRename: onRenameConversation,
                    onClose: { onCloseTab(session.id) }
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
