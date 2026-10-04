import SwiftUI

/// One project's tabs behind its group label, underlined in the group color along the tab bar's bottom edge, where the
/// selected tab covers the line as it joins its terminal. A collapsed group shows only its label.
struct TerminalTabGroupSection: View {
    @ObservedObject var store: ConversationStore
    let group: TerminalTabGroup<TerminalSession>
    let color: ThemeColor
    let isCollapsed: Bool
    let tabWidth: CGFloat
    let onToggleCollapsed: () -> Void
    /// The label's width with the space after it, which the bar leaves out of the room its tabs share.
    let onLabelWidthChange: (CGFloat) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void

    @State private var hoveredTabID: UUID?

    /// What the hidden tabs' CLIs are doing. A plain terminal runs no session, so it does not count.
    private func hiddenTabsActivity(_ hiddenTabs: [TerminalSession]) -> SessionActivitySummary {
        SessionActivitySummary(activities: hiddenTabs.filter { !$0.isPlainTerminal && $0.isRunning }.map(\.cliActivity))
    }

    var body: some View {
        let hiddenTabs = isCollapsed ? group.tabs : []
        let shownTabs = isCollapsed ? [] : group.tabs
        let projectName = store.projectDisplayName(forProjectPath: group.projectDirectoryKey)
        HStack(spacing: 0) {
            TerminalTabGroupLabel(
                projectName: projectName,
                location: ProjectLocation(key: group.projectDirectoryKey),
                color: color,
                tabCount: group.tabs.count,
                isCollapsed: isCollapsed,
                hiddenTabCount: hiddenTabs.count,
                hiddenTabsActivity: hiddenTabsActivity(hiddenTabs),
                onToggleCollapsed: onToggleCollapsed
            )
            .padding(.trailing, 6)
            .onGeometryChange(for: CGFloat.self, of: \.size.width, action: onLabelWidthChange)
            ForEach(Array(shownTabs.enumerated()), id: \.element.id) { index, session in
                TerminalTab(
                    session: session,
                    projectDisplayName: projectName,
                    hostDisplayName: store.hasRemoteHosts ? session.host.displayName : nil,
                    width: tabWidth,
                    isSelected: store.selectedTerminalID == session.id,
                    showsLeadingSeparator: index > 0 && !standsOut(session.id) && !standsOut(shownTabs[index - 1].id),
                    onHoverChange: { trackHover(of: session.id, isHovering: $0) },
                    onSelect: { store.selectTerminal(session.id) },
                    onRename: onRenameConversation,
                    onClose: { onCloseTab(session.id) }
                )
                .id(session.id)
            }
        }
        .background(alignment: .bottom) {
            Capsule()
                .fill(color.opacity(0.8))
                .frame(height: 2)
        }
    }

    /// The selected and the hovered tab draw a shape of their own, so no separator runs beside them.
    private func standsOut(_ tabID: UUID) -> Bool {
        tabID == store.selectedTerminalID || tabID == hoveredTabID
    }

    private func trackHover(of tabID: UUID, isHovering: Bool) {
        if isHovering {
            hoveredTabID = tabID
        } else if hoveredTabID == tabID {
            hoveredTabID = nil
        }
    }
}
