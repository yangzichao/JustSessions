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
            .onboardingTourStop(group.tabs.contains { $0.id == store.selectedTerminalID } ? .tabGroup : nil)
            .padding(.trailing, 6)
            .onGeometryChange(for: CGFloat.self, of: \.size.width, action: onLabelWidthChange)
            ForEach(Array(shownTabs.enumerated()), id: \.element.id) { index, session in
                let split = store.split(containing: session.id)
                TerminalTab(
                    session: session,
                    projectDisplayName: store.projectDisplayName(forProjectPath: session.projectDirectoryKey),
                    hostDisplayName: store.hasRemoteHosts ? session.host.displayName : nil,
                    width: split == nil ? tabWidth : WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth),
                    isSelected: store.selectedTerminalID == session.id,
                    isActive: isActive(session.id),
                    splitSide: split.flatMap { store.sides(of: $0)?.side(of: session.id) },
                    isSplitPartnerHovered: hoveredTabID.map { split?.partner(of: session.id) == $0 } ?? false,
                    showsLeadingSeparator: index > 0 && showsSeparator(between: shownTabs[index - 1].id, and: session.id),
                    splitMenu: splitMenu(for: session.id),
                    onHoverChange: { trackHover(of: session.id, isHovering: $0) },
                    onSelect: { store.selectTerminal(session.id) },
                    onRename: onRenameConversation,
                    onSplitAction: { perform($0, from: session.id) },
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
