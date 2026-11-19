import SwiftUI

struct TerminalSplitAcrossProjectsSection: View {
    let store: ConversationStore
    private var tabDragBetweenWindows: TabDragBetweenWindows { .shared }
    @Environment(\.tabHoverCards) private var hoverCards
    let split: TerminalSplit
    let tabs: [TerminalSession]
    let colorsByProjectKey: [String: ThemeColor]
    let tabWidth: CGFloat
    let onDragChanged: (_ translation: CGFloat) -> Void
    let onDragEnded: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void
    let onDeleteConversation: (Conversation) -> Void

    @State private var hoveredTabID: UUID?

    private static let gapBetweenTabs = 2 * WorkspaceTabMetrics.footRadius
    private static let endInset = WorkspaceTabMetrics.footRadius
    private static let cornerRadius = ThemeCornerRadius.panel.rawValue

    static let widthBesidesTabs = gapBetweenTabs + 2 * endInset

    var body: some View {
        let sides = store.sides(of: split)
        HStack(spacing: Self.gapBetweenTabs) {
            ForEach(tabs, id: \.id) { session in
                let color = colorsByProjectKey[session.projectDirectoryKey] ?? ThemePalette.ink
                let projectName = store.projectDisplayName(forProjectPath: session.projectDirectoryKey)
                TerminalTab(
                    session: session,
                    projectDisplayName: projectName,
                    hostDisplayName: store.hasRemoteHosts ? session.host.displayName : nil,
                    width: WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth),
                    isSelected: store.selectedTerminalID == session.id,
                    isActive: store.shownSplit?.id == split.id,
                    splitSide: sides?.side(of: session.id),
                    splitOrientation: store.orientation(ofSplitView: split.id),
                    drawsOwnShape: true,
                    isSplitPartnerHovered: hoveredTabID.map { split.partner(of: session.id) == $0 } ?? false,
                    showsLeadingSeparator: false,
                    groupColor: color,
                    deletesSessionWhenClosed: store.deletesSessionWhenClosed(session),
                    menuItems: TerminalTabMenuItems(
                        store: store, tab: session, onRename: onRenameConversation, onCloseTab: onCloseTab,
                        onDelete: onDeleteConversation
                    ),
                    onHoverChange: { trackHover(of: session.id, isHovering: $0) },
                    onSelect: { store.selectTerminal(session.id) },
                    onClose: { onCloseTab(session.id) }
                )
                .tabHoverCardAnchor(.tab(session.id))
                .id(session.id)
                .tabBarDrag(
                    onChanged: { translation, startLocation in drag(grabbing: session.id, by: translation, from: startLocation) },
                    onEnded: { drop(session.id) }
                )
                .reportsTabSpanInGroup(session.id, in: store)
            }
        }
        .padding(.horizontal, Self.endInset)
        .background {
            VStack(spacing: 0) {
                UnevenRoundedRectangle(topLeadingRadius: Self.cornerRadius, topTrailingRadius: Self.cornerRadius, style: .continuous)
                    .fill(ThemePalette.trackFill)
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.id) { session in
                        Capsule().fill(colorsByProjectKey[session.projectDirectoryKey] ?? ThemePalette.ink)
                    }
                }
                .frame(height: WorkspaceTabMetrics.groupLineWidth)
            }
        }
        .tabBarGroupCoordinateSpace()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Split view across projects")
    }

    private func drag(grabbing tabID: UUID, by translation: CGFloat, from startLocation: CGPoint) {
        guard
            tabDragBetweenWindows.followDragInTabBar(
                of: tabs.map(\.id),
                grabbing: tabID,
                inGroup: split.groupKey,
                of: store,
                from: startLocation
            )
        else { return }
        onDragChanged(translation)
    }

    private func drop(_ tabID: UUID) {
        tabDragBetweenWindows.endDragInTabBar()
        onDragEnded()
        if store.terminalSessions.contains(where: { $0.id == tabID }) { store.selectTerminal(tabID) }
    }

    private func trackHover(of tabID: UUID, isHovering: Bool) {
        if isHovering {
            hoveredTabID = tabID
            hoverCards?.pointerEntered(.tab(tabID), tabWidth: WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth))
        } else {
            if hoveredTabID == tabID { hoveredTabID = nil }
            hoverCards?.pointerExited(.tab(tabID))
        }
    }
}
