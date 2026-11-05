import SwiftUI

/// A split across two projects in the tab bar: a container of its own among the groups, with no label, holding the
/// split's two tabs as smaller tabs of their own, each in its project's color and with its project's name, hover
/// card, and menus, so neither tab leaves its project for the other's. The container is a track under the two tabs,
/// underlined half in each project's color along the tab bar's bottom edge, which the selected tab covers as it joins
/// its terminal. Dragging either tab moves the whole split among the groups, which the tab bar moves, or on between
/// windows, see `TabDragBetweenWindows`.
struct TerminalSplitAcrossProjectsSection: View {
    let store: ConversationStore
    private var tabDragBetweenWindows: TabDragBetweenWindows { .shared }
    @Environment(\.tabHoverCards) private var hoverCards
    let split: TerminalSplit
    /// The split's two tabs, the left pane's first.
    let tabs: [TerminalSession]
    let colorsByProjectKey: [String: ThemeColor]
    /// The width of a tab in no split; each of the split's is half as wide.
    let tabWidth: CGFloat
    let onDragChanged: (_ translation: CGFloat) -> Void
    let onDragEnded: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void
    let onDeleteConversation: (Conversation) -> Void

    @State private var hoveredTabID: UUID?

    /// Room between the two tabs for both their feet, which curve out past their sides.
    private static let gapBetweenTabs = 2 * WorkspaceTabMetrics.footRadius
    /// Room at the container's ends for the outer feet.
    private static let endInset = WorkspaceTabMetrics.footRadius
    private static let cornerRadius = ThemeCornerRadius.panel.rawValue

    /// The container's width past its two tabs', which the bar leaves out of the room its tabs share.
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
                // The track sits on the underline, so each half of the line is in its project's color on the bar's
                // surface, as a group's underline is.
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

    /// Moves the split among the groups as the pointer moves along the bar, until the drag goes on between windows.
    private func drag(grabbing tabID: UUID, by translation: CGFloat, from startLocation: CGPoint) {
        guard tabDragBetweenWindows.followDragInTabBar(
            of: tabs.map(\.id),
            grabbing: tabID,
            inGroup: split.groupKey,
            of: store,
            from: startLocation
        ) else { return }
        onDragChanged(translation)
    }

    /// Leaves the split where it was let go and shows the grabbed tab, as a click on it would.
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
