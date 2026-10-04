import SwiftUI

/// The open tabs, grouped by project like tab groups in a browser: each project's tabs sit together behind a label
/// in the project's color, which collapses or expands the group. Selecting a tab of a collapsed group, by shortcut or
/// from the sidebar, expands it, as does the selected tab moving into a collapsed group, such as when it leaves a
/// split in another project's group. The bar sits in the title bar, in the sidebar's color, like a browser's tab strip:
/// the selected tab takes its terminal's color and runs down into it, through the bar's bottom line. As in Chrome,
/// tabs narrow together to fit the bar as more open, and the bar scrolls once they are as narrow as they get; a split's
/// two tabs share one tab's width.
struct WorkspaceTabBar: View {
    @ObservedObject var store: ConversationStore
    /// Width at the leading edge that tabs never enter, even when scrolled, so the window buttons and sidebar toggle
    /// stay clear of them.
    let leadingClearance: CGFloat
    let onRenameConversation: (Conversation) -> Void
    let onCloseTerminal: (UUID) -> Void
    @State private var collapsedProjectKeys: Set<String> = []
    /// The bar's visible width, past the leading clearance. Until measured, tabs take their full width.
    @State private var barWidth: CGFloat = .infinity
    @State private var groupLabelWidthsByProjectKey: [String: CGFloat] = [:]

    var body: some View {
        let groups = TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: store.tabGroupKey(of:))
        let colorsByProjectKey = TabGroupPalette.colorsByProjectKey(groups.map(\.projectDirectoryKey))
        let shownTabs = groups
            .filter { !collapsedProjectKeys.contains($0.projectDirectoryKey) }
            .flatMap(\.tabs)
        // A split's two tabs, always in one group, take one tab's place.
        let shownSplitCount = store.terminalSplits.filter { split in shownTabs.contains { split.contains($0.id) } }.count
        let shownTabCount = shownTabs.count - shownSplitCount
        let tabWidth = WorkspaceTabWidth.fitting(
            shownTabCount: shownTabCount,
            shownSplitCount: shownSplitCount,
            groupCount: groups.count,
            groupLabelsWidth: groups.compactMap { groupLabelWidthsByProjectKey[$0.projectDirectoryKey] }.reduce(0, +),
            barWidth: barWidth
        )
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal) {
                HStack(spacing: WorkspaceTabMetrics.groupSpacing) {
                    ForEach(groups) { group in
                        TerminalTabGroupSection(
                            store: store,
                            group: group,
                            color: colorsByProjectKey[group.projectDirectoryKey] ?? ThemePalette.ink,
                            isCollapsed: collapsedProjectKeys.contains(group.projectDirectoryKey),
                            tabWidth: tabWidth,
                            onToggleCollapsed: { toggleCollapsed(group.projectDirectoryKey) },
                            onLabelWidthChange: { groupLabelWidthsByProjectKey[group.projectDirectoryKey] = $0 },
                            onRenameConversation: onRenameConversation,
                            onCloseTab: onCloseTerminal
                        )
                    }
                }
                .padding(.horizontal, WorkspaceTabMetrics.horizontalInset)
                .padding(.top, WorkspaceTabMetrics.topInset)
                // Tabs narrow or widen smoothly as others open or close; resizing the window moves them directly.
                .animation(.easeOut(duration: 0.15), value: shownTabCount)
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { barWidth = $0 }
            .onChange(of: store.selectedTerminalID) { revealSelectedTab(scrollProxy) }
            .onChange(of: store.selectedTerminal.map(store.tabGroupKey(of:))) { revealSelectedTab(scrollProxy) }
        }
        .padding(.leading, leadingClearance)
        .background {
            ZStack(alignment: .bottom) {
                Rectangle().fill(ThemePalette.sidebarSurface)
                ThemeDivider()
            }
        }
        .tabBarTerminalPalette(from: .shared)
        .onChange(of: groups.map(\.projectDirectoryKey)) { _, openProjectKeys in
            // A project whose last tab closed opens expanded next time.
            collapsedProjectKeys.formIntersection(openProjectKeys)
            groupLabelWidthsByProjectKey = groupLabelWidthsByProjectKey.filter { openProjectKeys.contains($0.key) }
        }
    }

    private func toggleCollapsed(_ projectKey: String) {
        if collapsedProjectKeys.contains(projectKey) {
            expandGroup(projectKey)
            return
        }
        // Show another tab first, so the group's selected tab does not hide while its terminal stays in front.
        selectTabInSight(insteadOfTabsIn: projectKey)
        withAnimation(.easeOut(duration: 0.15)) {
            _ = collapsedProjectKeys.insert(projectKey)
        }
    }

    /// Expands the selected tab's group if it is collapsed, and scrolls the tab into sight.
    private func revealSelectedTab(_ scrollProxy: ScrollViewProxy) {
        guard let selectedTerminal = store.selectedTerminal else { return }
        let groupKey = store.tabGroupKey(of: selectedTerminal)
        if collapsedProjectKeys.contains(groupKey) {
            expandGroup(groupKey)
        }
        scrollProxy.scrollTo(selectedTerminal.id, anchor: .center)
    }

    private func expandGroup(_ projectKey: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            _ = collapsedProjectKeys.remove(projectKey)
        }
    }

    /// With every other tab in a collapsed group too, the selected tab keeps showing behind its collapsed label.
    private func selectTabInSight(insteadOfTabsIn projectKey: String) {
        let tabProjectKeys = store.tabGroupKeys
        guard let selectedIndex = store.terminalSessions.firstIndex(where: { $0.id == store.selectedTerminalID }),
              tabProjectKeys[selectedIndex] == projectKey,
              let indexToSelect = TerminalTabOrder.indexToSelect(
                  afterCollapsingGroupOfTabAt: selectedIndex,
                  collapsedProjectKeys: collapsedProjectKeys,
                  amongTabProjectKeys: tabProjectKeys
              ) else { return }
        store.selectTerminal(store.terminalSessions[indexToSelect].id)
    }
}
