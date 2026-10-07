import SwiftUI

/// One project's tabs behind its group label, underlined in the group color along the tab bar's bottom edge, where the
/// selected tab covers the line as it joins its terminal. A collapsed group shows only its label. A tab drags among the
/// group's tabs, with the other tab of its split, and shows once dropped; the label drags the whole group, which the
/// tab bar moves.
struct TerminalTabGroupSection: View {
    @ObservedObject var store: ConversationStore
    let group: TerminalTabGroup<TerminalSession>
    let color: ThemeColor
    let isCollapsed: Bool
    let tabWidth: CGFloat
    let onToggleCollapsed: () -> Void
    /// The label's width with the space after it, which the bar leaves out of the room its tabs share.
    let onLabelWidthChange: (CGFloat) -> Void
    let onLabelDragChanged: (_ translation: CGFloat) -> Void
    let onLabelDragEnded: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void

    @State private var hoveredTabID: UUID?
    /// The tab, or split, being dragged among the group's tabs and splits, each named by its tabs' ids.
    @State private var tabDrag: TabBarDrag<[UUID]>?

    var body: some View {
        let hiddenTabs = isCollapsed ? group.tabs : []
        let shownTabs = isCollapsed ? [] : group.tabs
        let movingUnits = isCollapsed ? [] : store.tabStrip.movingUnits(inGroup: group.projectDirectoryKey)
        // A drag begun before a tab of the group opened or closed is no longer drawn, and is let go once the bar
        // catches up; see the `onChange` below.
        let currentTabDrag = tabDrag.flatMap { $0.itemIDs == movingUnits ? $0 : nil }
        let tabIDsInSight = currentTabDrag.map { Array($0.orderedItemIDs.joined()) } ?? shownTabs.map(\.id)
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
                onToggleCollapsed: onToggleCollapsed
            )
            .tabBarDrag(onChanged: onLabelDragChanged, onEnded: onLabelDragEnded)
            .onboardingTourStop(group.tabs.contains { $0.id == store.selectedTerminalID } ? .tabGroup : nil)
            .padding(.trailing, 6)
            .onGeometryChange(for: CGFloat.self, of: \.size.width, action: onLabelWidthChange)
            ForEach(shownTabs, id: \.id) { session in
                let split = store.split(containing: session.id)
                let movingUnit = movingUnits.first { $0.contains(session.id) } ?? [session.id]
                let isDragged = currentTabDrag?.draggedID == movingUnit
                TerminalTab(
                    session: session,
                    projectDisplayName: store.projectDisplayName(forProjectPath: session.projectDirectoryKey),
                    hostDisplayName: store.hasRemoteHosts ? session.host.displayName : nil,
                    width: width(ofTab: session.id),
                    isSelected: store.selectedTerminalID == session.id,
                    isActive: isActive(session.id),
                    splitSide: split.flatMap { store.sides(of: $0)?.side(of: session.id) },
                    isSplitPartnerHovered: hoveredTabID.map { split?.partner(of: session.id) == $0 } ?? false,
                    showsLeadingSeparator: tabBefore(session.id, in: tabIDsInSight).map { showsSeparator(between: $0, and: session.id) } ?? false,
                    splitMenu: splitMenu(for: session.id),
                    newSessionMenu: newSessionMenu(inGroupOf: session, projectName: projectName),
                    onHoverChange: { trackHover(of: session.id, isHovering: $0) },
                    onSelect: { store.selectTerminal(session.id) },
                    onRename: onRenameConversation,
                    onSplitAction: { perform($0, from: session.id) },
                    onClose: { onCloseTab(session.id) }
                )
                .id(session.id)
                .offset(x: currentTabDrag?.offset(of: movingUnit) ?? 0)
                // The tabs the dragged one passes slide over; it follows the pointer itself.
                .animation(isDragged ? nil : TabBarDragMetrics.slideAnimation, value: currentTabDrag?.targetIndex)
                .zIndex(isDragged ? 1 : 0)
                .tabBarDrag(
                    onChanged: { dragTab(session.id, by: $0, among: movingUnits) },
                    onEnded: { dropDraggedTab(session.id) }
                )
            }
        }
        .onChange(of: movingUnits) { tabDrag = nil }
        .background(alignment: .bottom) {
            Capsule()
                .fill(color.opacity(0.8))
                .frame(height: 2)
        }
    }

    /// The new session menu of a tab's context menu, the same as its project's + in the sidebar, which opens the new
    /// tab in this group.
    private func newSessionMenu(inGroupOf tab: TerminalSession, projectName: String) -> ProjectNewSessionMenu {
        let location = store.groupLocation(of: tab)
        return ProjectNewSessionMenu(
            location: location,
            projectDisplayName: projectName,
            providers: store.newSessionProviders(on: location.host),
            showsTitle: true,
            onStart: { store.launchNewSession(provider: $0, inGroupOf: tab) },
            onOpenTerminal: { store.openPlainTerminal(inGroupOf: tab) }
        )
    }

    /// A split's tab is half as wide as the others, so the split's two take one tab's place.
    private func width(ofTab tabID: UUID) -> CGFloat {
        store.split(containing: tabID) == nil ? tabWidth : WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth)
    }

    /// The tab drawn right before this one, in the order the tabs show in mid-drag.
    private func tabBefore(_ tabID: UUID, in tabIDsInSight: [UUID]) -> UUID? {
        guard let index = tabIDsInSight.firstIndex(of: tabID), index > 0 else { return nil }
        return tabIDsInSight[index - 1]
    }

    /// Starts dragging the tab, with the other tab of its split, among the group's tabs and splits as they are now,
    /// or follows the pointer once it has started.
    private func dragTab(_ tabID: UUID, by translation: CGFloat, among movingUnits: [[UUID]]) {
        if tabDrag?.draggedID.contains(tabID) != true, let movingUnit = movingUnits.first(where: { $0.contains(tabID) }) {
            let widths = movingUnits.map { $0.map(width(ofTab:)).reduce(0, +) }
            tabDrag = TabBarDrag(dragging: movingUnit, among: movingUnits, widths: widths, spacing: 0)
        }
        tabDrag?.translation = translation
    }

    /// Moves the dragged tab to where it was let go, unless a tab of the group opened or closed meanwhile, and shows
    /// it, as a click on it would.
    private func dropDraggedTab(_ tabID: UUID) {
        guard let tabDrag else { return }
        let stillMatches = tabDrag.itemIDs == store.tabStrip.movingUnits(inGroup: group.projectDirectoryKey)
        withAnimation(TabBarDragMetrics.slideAnimation) {
            if stillMatches { store.moveTab(tabID, toPlaceInGroup: tabDrag.targetIndex) }
            self.tabDrag = nil
        }
        store.selectTerminal(tabID)
    }

    /// The split entries Chrome's tab menu offers for the tab: a tab in a split arranges it; any other tab can open
    /// in a new split with the selected tab while that is in none, or take a place in its split while it is in one.
    private func splitMenu(for tabID: UUID) -> TerminalTabSplitMenu? {
        if store.split(containing: tabID) != nil { return .arrangeSplit }
        guard let selectedTerminalID = store.selectedTerminalID else { return nil }
        if store.split(containing: selectedTerminalID) != nil { return .moveIntoShownSplit }
        guard tabID == selectedTerminalID else { return .newSplitWithSelectedTab }
        let candidates = store.terminalSessions
            .filter { $0.id != tabID && store.split(containing: $0.id) == nil }
            .map { TerminalTabSplitCandidate(session: $0, projectDisplayName: store.projectDisplayName(forProjectPath: $0.projectDirectoryKey)) }
        return .addTabToNewSplit(candidates: candidates)
    }

    /// Acts on the tab's split entry. The views a split entry closes go through the same close request as their ×.
    private func perform(_ action: TerminalTabSplitAction, from tabID: UUID) {
        switch action {
        case .newSplitWithSelectedTab:
            store.splitSelectedTerminal(with: tabID)
        case .addToNewSplit(let otherTabID):
            store.splitSelectedTerminal(with: otherTabID)
        case .moveIntoShownSplit(let side):
            store.moveIntoShownSplit(tabID, swappingWith: side)
        case .separateViews:
            if let split = store.split(containing: tabID) { store.separateSplit(split.id) }
        case .closeView(let side):
            if let split = store.split(containing: tabID), let sides = store.sides(of: split) {
                onCloseTab(sides.tabID(on: side))
            }
        case .reverseViews:
            if let split = store.split(containing: tabID) { store.reverseSplit(split.id) }
        }
    }

    /// Drawn as the selected tab: the selected tab and the other tab of its split.
    private func isActive(_ tabID: UUID) -> Bool {
        tabID == store.selectedTerminalID || store.shownSplit?.contains(tabID) == true
    }

    /// Under the pointer, itself or through the other tab of its split.
    private func isLitByHover(_ tabID: UUID) -> Bool {
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
    }
}
