import SwiftUI

/// One project's tabs behind its group label, underlined in the group color along the tab bar's bottom edge. The
/// selected tab covers the line as it joins its terminal, and its outline in the group color rises from the line. A collapsed group shows only its label. A tab drags among the
/// group's tabs, with the other tab of its split, and shows once dropped; dragged off the bar, it goes on between
/// windows, see `TabDragBetweenWindows`, which also draws tabs dragged in from another window among the group's. The
/// label drags the whole group, which the tab bar moves, and which goes on between windows once dragged off the bar.
struct TerminalTabGroupSection: View {
    let store: ConversationStore
    @Environment(\.tabHoverCards) private var hoverCards
    let group: TerminalTabGroup<TerminalSession>
    let color: ThemeColor
    let isCollapsed: Bool
    let tabWidth: CGFloat
    let onToggleCollapsed: () -> Void
    let allGroups: AllTabGroupsCollapsing
    /// The label's width with the space after it, which the bar leaves out of the room its tabs share.
    let onLabelWidthChange: (CGFloat) -> Void
    /// The label's drag along the bar, which moves the group among the groups until it goes on between windows.
    let onLabelDragChanged: (_ translation: CGFloat) -> Void
    let onLabelDragEnded: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void
    let onDeleteConversation: (Conversation) -> Void
    /// Closes the group's tabs, asking once for them all; see `SeveralTabsCloseConfirmation`.
    let onCloseTabs: ([UUID], _ projectName: String) -> Void

    @State private var hoveredTabID: UUID?
    /// The tab whose split chooser's half is under the pointer, which lights the tab too.
    @State private var hoveredSplitChooserTabID: UUID?
    /// The tab, or split, being dragged among the group's tabs and splits, each named by its tabs' ids.
    @State private var tabDrag = TabBarDragDisplay<[UUID]>()

    private var tabDragBetweenWindows: TabDragBetweenWindows { .shared }

    var body: some View {
        let hiddenTabs = isCollapsed ? group.tabs : []
        let shownTabs = isCollapsed ? [] : group.tabs
        let movingUnits = isCollapsed ? [] : store.tabStrip.movingUnits(inGroup: group.projectDirectoryKey)
        // A drag begun before a tab of the group opened or closed is no longer drawn, and is let go once the bar
        // catches up; see the `onChange` below. Tabs dragged in from another window, such as a whole group's, move
        // together as one.
        let groupKey = group.projectDirectoryKey
        let dragDisplays = tabDragBetweenWindows.dragDisplays(in: store)
        let tabDragsInGroup = [tabDrag, dragDisplays.amongTabs(ofGroup: groupKey)]
        let shownTabDrag = isCollapsed ? nil : tabDragsInGroup.first { display in
            guard let placement = display.placement else { return false }
            return placement.itemIDs == store.tabStrip.movingUnits(inGroup: groupKey, keepingTogether: placement.draggedID)
        }
        let tabDragPlacement = shownTabDrag?.placement
        let tabIDsInSight = tabDragPlacement.map { Array($0.orderedItemIDs.joined()) } ?? shownTabs.map(\.id)
        let projectName = store.projectDisplayName(forProjectPath: group.projectDirectoryKey)
        HStack(spacing: 0) {
            TerminalTabGroupLabel(
                projectName: projectName,
                location: ProjectLocation(key: group.projectDirectoryKey),
                color: color,
                tabCount: group.tabs.count,
                isCollapsed: isCollapsed,
                hiddenTabCount: hiddenTabs.count,
                hiddenTabsActivity: SessionActivitySummary(tabs: hiddenTabs),
                onToggleCollapsed: onToggleCollapsed,
                menuItems: TabGroupMenuItems(
                    store: store,
                    projectKey: group.projectDirectoryKey,
                    projectDisplayName: projectName,
                    isCollapsed: isCollapsed,
                    onToggleCollapsed: onToggleCollapsed,
                    allGroups: allGroups,
                    onCloseTabs: { onCloseTabs(group.tabs.map(\.id), projectName) }
                )
            )
            .tabHoverCardAnchor(.group(group.projectDirectoryKey))
            .onHover { trackHover(of: .group(group.projectDirectoryKey), isHovering: $0) }
            .tabBarDrag(onChanged: dragGroup, onEnded: dropDraggedGroup)
            .onboardingTourStop(group.tabs.contains { $0.id == store.selectedTerminalID } ? .tabGroup : nil)
            .padding(.trailing, 6)
            .onGeometryChange(for: CGFloat.self, of: \.size.width, action: onLabelWidthChange)
            ForEach(shownTabs, id: \.id) { session in
                let movingUnit = movingUnits.first { $0.contains(session.id) } ?? [session.id]
                let dragItem = tabDragPlacement?.itemIDs.first { $0.contains(session.id) } ?? movingUnit
                let showsLeadingSeparator = tabBefore(session.id, in: tabIDsInSight).map { showsSeparator(between: $0, and: session.id) } ?? false
                tabUnit(of: session, showsLeadingSeparator: showsLeadingSeparator)
                .id(session.id)
                .tabBarDragShift(of: dragItem, in: shownTabDrag)
                .opacity(dragDisplays.leavingTabIDs.contains(session.id) ? 0 : 1)
                .tabBarDrag(
                    onChanged: { dragTab(session.id, by: $0, from: $1, among: movingUnits) },
                    onEnded: { dropDraggedTab(session.id) }
                )
                .reportsTabSpanInGroup(session.id, in: store)
            }
        }
        .tabBarGroupCoordinateSpace()
        .onChange(of: movingUnits) { tabDrag.show(nil) }
        .background(alignment: .bottom) {
            // Opaque, so it meets the selected tab's outline without a brighter seam where the two overlap.
            Capsule()
                .fill(color)
                .frame(height: WorkspaceTabMetrics.groupLineWidth)
        }
    }

    /// The tab, joined with its split chooser's half when it has a chooser, as a split's two tabs join.
    @ViewBuilder
    private func tabUnit(of session: TerminalSession, showsLeadingSeparator: Bool) -> some View {
        if let chooser = store.splitChooser(beside: session.id) {
            let halfWidth = WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth)
            HStack(spacing: 0) {
                if chooser.side == .left { splitChooserTab(beside: session, side: .left, width: halfWidth, showsLeadingSeparator: showsLeadingSeparator) }
                terminalTab(
                    session,
                    width: halfWidth,
                    splitSide: chooser.tabSide,
                    isPartnerHovered: hoveredSplitChooserTabID == session.id,
                    showsLeadingSeparator: chooser.side == .right && showsLeadingSeparator
                )
                if chooser.side == .right { splitChooserTab(beside: session, side: .right, width: halfWidth, showsLeadingSeparator: false) }
            }
        } else {
            let split = store.split(containing: session.id)
            terminalTab(
                session,
                width: width(ofTab: session.id),
                splitSide: split.flatMap { store.sides(of: $0)?.side(of: session.id) },
                isPartnerHovered: hoveredTabID.map { split?.partner(of: session.id) == $0 } ?? false,
                showsLeadingSeparator: showsLeadingSeparator
            )
        }
    }

    private func terminalTab(
        _ session: TerminalSession,
        width: CGFloat,
        splitSide: TerminalSplit.Side?,
        isPartnerHovered: Bool,
        showsLeadingSeparator: Bool
    ) -> some View {
        TerminalTab(
            session: session,
            projectDisplayName: store.projectDisplayName(forProjectPath: session.projectDirectoryKey),
            hostDisplayName: store.hasRemoteHosts ? session.host.displayName : nil,
            width: width,
            isSelected: store.selectedTerminalID == session.id && !(store.selectsShownSplitChooser && store.splitChooser(beside: session.id) != nil),
            isActive: isActive(session.id),
            splitSide: splitSide,
            isSplitPartnerHovered: isPartnerHovered,
            showsLeadingSeparator: showsLeadingSeparator,
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
    }

    /// The half of the split tab that stands for the split chooser beside `session`.
    private func splitChooserTab(beside session: TerminalSession, side: TerminalSplit.Side, width: CGFloat, showsLeadingSeparator: Bool) -> some View {
        let isShown = store.selectedTerminalID == session.id
        return TerminalSplitChooserTab(
            width: width,
            isSelected: isShown && store.selectsShownSplitChooser,
            isActive: isShown,
            side: side,
            isPartnerHovered: hoveredTabID == session.id,
            showsLeadingSeparator: showsLeadingSeparator,
            groupColor: color,
            menuItems: TerminalTabSplitMenuItems(splitMenu: store.splitMenu(forTab: session.id)) { action in
                store.performSplitAction(action, fromTab: session.id, closeTab: onCloseTab)
            },
            onHoverChange: { isHovering in
                if isHovering {
                    hoveredSplitChooserTabID = session.id
                } else if hoveredSplitChooserTabID == session.id {
                    hoveredSplitChooserTabID = nil
                }
            },
            onSelect: { store.selectSplitChooser(beside: session.id) },
            onClose: { if let chooser = store.splitChooser(beside: session.id) { store.closeSplitChooser(chooser.id) } }
        )
    }

    /// A split's tab is half as wide as the others, so the split's two take one tab's place, as a tab and its split
    /// chooser's half do.
    private func width(ofTab tabID: UUID) -> CGFloat {
        if store.splitChooser(beside: tabID) != nil { return 2 * WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth) }
        return store.split(containing: tabID) == nil ? tabWidth : WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth)
    }

    /// The tab drawn right before this one, in the order the tabs show in mid-drag.
    private func tabBefore(_ tabID: UUID, in tabIDsInSight: [UUID]) -> UUID? {
        guard let index = tabIDsInSight.firstIndex(of: tabID), index > 0 else { return nil }
        return tabIDsInSight[index - 1]
    }

    /// Moves the group among the groups as the pointer moves along the bar, until the drag goes on between windows.
    private func dragGroup(by translation: CGFloat, from startLocation: CGPoint) {
        guard tabDragBetweenWindows.followGroupDragInTabBar(group.projectDirectoryKey, of: store, from: startLocation) else { return }
        onLabelDragChanged(translation)
    }

    /// Leaves the group where it was let go along the bar.
    private func dropDraggedGroup() {
        tabDragBetweenWindows.endDragInTabBar()
        onLabelDragEnded()
    }

    /// Starts dragging the tab, with the other tab of its split, among the group's tabs and splits as they are now,
    /// or follows the pointer once it has started, until the drag goes on between windows.
    private func dragTab(_ tabID: UUID, by translation: CGFloat, from startLocation: CGPoint, among movingUnits: [[UUID]]) {
        guard let movingUnit = movingUnits.first(where: { $0.contains(tabID) }) else { return }
        guard tabDragBetweenWindows.followDragInTabBar(
            of: movingUnit,
            grabbing: tabID,
            inGroup: group.projectDirectoryKey,
            of: store,
            from: startLocation
        ) else {
            // Leaving for a window of their own, the tabs stay hidden where they were drawn until they go, so nothing
            // slides back meanwhile.
            if !tabDragBetweenWindows.dragDisplays(in: store).leavingTabIDs.contains(tabID) { tabDrag.show(nil) }
            return
        }
        var drag = tabDrag.drag
        if drag?.draggedID.contains(tabID) != true {
            let widths = movingUnits.map { $0.map(width(ofTab:)).reduce(0, +) }
            drag = TabBarDrag(dragging: movingUnit, among: movingUnits, widths: widths, spacing: 0)
        }
        drag?.translation = translation
        tabDrag.show(drag)
    }

    /// Moves the dragged tab to where it was let go, unless a tab of the group opened or closed meanwhile, and shows
    /// it, as a click on it would.
    private func dropDraggedTab(_ tabID: UUID) {
        tabDragBetweenWindows.endDragInTabBar()
        guard let drag = tabDrag.drag else { return }
        let stillMatches = drag.itemIDs == store.tabStrip.movingUnits(inGroup: group.projectDirectoryKey)
        withAnimation(TabBarDragMetrics.slideAnimation) {
            if stillMatches { store.moveTab(tabID, toPlaceInGroup: drag.targetIndex) }
            tabDrag.show(nil)
        }
        store.selectTerminal(tabID)
    }

    /// Drawn as the selected tab: the selected tab and the other tab of its split.
    private func isActive(_ tabID: UUID) -> Bool {
        tabID == store.selectedTerminalID || store.shownSplit?.contains(tabID) == true
    }

    /// Under the pointer, itself or through the other tab of its split or its split chooser's half.
    private func isLitByHover(_ tabID: UUID) -> Bool {
        if hoveredSplitChooserTabID == tabID { return true }
        guard let hoveredTabID else { return false }
        return tabID == hoveredTabID || store.split(containing: hoveredTabID)?.contains(tabID) == true
    }

    /// No separator runs beside a tab drawing a shape of its own, active or under the pointer, nor between a split's
    /// two tabs, which join into one shape.
    private func showsSeparator(between previousTabID: UUID, and tabID: UUID) -> Bool {
        let standsOut = { (tabID: UUID) in self.isActive(tabID) || self.isLitByHover(tabID) }
        let isSameSplit = store.split(containing: tabID)?.contains(previousTabID) == true
        return !standsOut(previousTabID) && !standsOut(tabID) && !isSameSplit
    }

    private func trackHover(of tabID: UUID, isHovering: Bool) {
        if isHovering {
            hoveredTabID = tabID
        } else if hoveredTabID == tabID {
            hoveredTabID = nil
        }
        trackHover(of: .tab(tabID), isHovering: isHovering)
    }

    /// Tells the window's hover card where the pointer is.
    private func trackHover(of target: TabHoverCardTarget, isHovering: Bool) {
        if isHovering {
            hoverCards?.pointerEntered(target, tabWidth: tabWidth)
        } else {
            hoverCards?.pointerExited(target)
        }
    }
}
