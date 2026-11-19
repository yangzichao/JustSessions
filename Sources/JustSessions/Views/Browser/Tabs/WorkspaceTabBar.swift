import SwiftUI

struct WorkspaceTabBar: View {
    let store: ConversationStore
    let leadingClearance: CGFloat
    let onRenameConversation: (Conversation) -> Void
    let onNewSession: () -> Void
    let onCloseTerminal: (UUID) -> Void
    let onDeleteConversation: (Conversation) -> Void
    let onCloseTabGroup: ([UUID], _ projectName: String) -> Void
    @State private var collapsedProjectKeys: Set<String> = []
    @State private var barWidth: CGFloat = .infinity
    @State private var groupLabelWidthsByProjectKey: [String: CGFloat] = [:]
    @State private var groupWidthsByProjectKey: [String: CGFloat] = [:]
    @State private var groupDrag = TabBarDragDisplay<String>()

    var body: some View {
        let groups = TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: store.tabGroupKey(of:))
        let groupKeys = groups.map(\.projectDirectoryKey)
        let colorsByProjectKey = TabGroupPalette.colorsByProjectKey(store.tabProjectKeysInOrder)
        let dragDisplays = TabDragBetweenWindows.shared.dragDisplays(in: store)
        let groupDragsInBar = [groupDrag, dragDisplays.amongGroups]
        let shownGroupDrag = groupDragsInBar.first { $0.placement?.itemIDs == groupKeys }
        let shownTabs =
            groups
            .filter { !collapsedProjectKeys.contains($0.projectDirectoryKey) }
            .flatMap(\.tabs)
        let shownSplitCount = store.terminalSplits.filter { split in shownTabs.contains { split.contains($0.id) } }.count
        let shownTabCount = shownTabs.count - shownSplitCount
        let shownSplitChooserCount = store.terminalSplitChoosers.filter { chooser in shownTabs.contains { $0.id == chooser.tabID } }.count
        let groupLabelsWidth = groups.reduce(CGFloat(0)) { width, group in
            TerminalSplit.isGroupKeyOfSplitAcrossProjects(group.projectDirectoryKey)
                ? width + TerminalSplitAcrossProjectsSection.widthBesidesTabs
                : width + (groupLabelWidthsByProjectKey[group.projectDirectoryKey] ?? 0)
        }
        let tabWidth = WorkspaceTabWidth.fitting(
            shownTabCount: shownTabCount,
            shownSplitCount: shownSplitCount + shownSplitChooserCount,
            groupCount: groups.count,
            groupLabelsWidth: groupLabelsWidth,
            barWidth: barWidth
        )
        let allGroups = allGroupsCollapsing(groupKeys)
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal) {
                HStack(spacing: WorkspaceTabMetrics.groupSpacing) {
                    ForEach(groups) { group in
                        Group {
                            if let split = store.terminalSplits.first(where: {
                                $0.spansProjects && $0.groupKey == group.projectDirectoryKey
                            }) {
                                TerminalSplitAcrossProjectsSection(
                                    store: store,
                                    split: split,
                                    tabs: group.tabs,
                                    colorsByProjectKey: colorsByProjectKey,
                                    tabWidth: tabWidth,
                                    onDragChanged: { dragGroup(group.projectDirectoryKey, by: $0, among: groupKeys) },
                                    onDragEnded: dropDraggedGroup,
                                    onRenameConversation: onRenameConversation,
                                    onCloseTab: onCloseTerminal,
                                    onDeleteConversation: onDeleteConversation
                                )
                            } else {
                                TerminalTabGroupSection(
                                    store: store,
                                    group: group,
                                    color: colorsByProjectKey[group.projectDirectoryKey] ?? ThemePalette.ink,
                                    isCollapsed: collapsedProjectKeys.contains(group.projectDirectoryKey),
                                    tabWidth: tabWidth,
                                    onToggleCollapsed: { toggleCollapsed(group.projectDirectoryKey) },
                                    allGroups: allGroups,
                                    onLabelWidthChange: { groupLabelWidthsByProjectKey[group.projectDirectoryKey] = $0 },
                                    onLabelDragChanged: { dragGroup(group.projectDirectoryKey, by: $0, among: groupKeys) },
                                    onLabelDragEnded: dropDraggedGroup,
                                    onRenameConversation: onRenameConversation,
                                    onCloseTab: onCloseTerminal,
                                    onDeleteConversation: onDeleteConversation,
                                    onCloseTabs: onCloseTabGroup
                                )
                            }
                        }
                        .onGeometryChange(for: CGFloat.self, of: \.size.width) { groupWidthsByProjectKey[group.projectDirectoryKey] = $0 }
                        .tabBarDragShift(of: group.projectDirectoryKey, in: shownGroupDrag)
                        .opacity(group.tabs.allSatisfy { dragDisplays.leavingTabIDs.contains($0.id) } ? 0 : 1)
                        .reportsTabBarGroupSpan(group.projectDirectoryKey, in: store)
                    }
                }
                .padding(.horizontal, WorkspaceTabMetrics.horizontalInset)
                .padding(.top, WorkspaceTabMetrics.topInset)
                .animation(ThemeMotion.slide, value: shownTabCount)
            }
            .scrollIndicators(.never)
            .contextMenu { TabGroupsBackgroundMenuItems(onNewSession: onNewSession, allGroups: allGroups) }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { barWidth = $0 }
            .windowMoveZone()
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
        .tabBarTerminalPalette(from: .shared, themeStore: .shared)
        .onChange(of: groups.map(\.projectDirectoryKey)) { _, openProjectKeys in
            collapsedProjectKeys.formIntersection(openProjectKeys)
            groupLabelWidthsByProjectKey = groupLabelWidthsByProjectKey.filter { openProjectKeys.contains($0.key) }
            groupWidthsByProjectKey = groupWidthsByProjectKey.filter { openProjectKeys.contains($0.key) }
            groupDrag.show(nil)
        }
    }

    private func dragGroup(_ projectKey: String, by translation: CGFloat, among groupKeys: [String]) {
        var drag = groupDrag.drag
        if drag?.draggedID != projectKey {
            drag = TabBarDrag(
                dragging: projectKey,
                among: groupKeys,
                widths: groupKeys.compactMap { groupWidthsByProjectKey[$0] },
                spacing: WorkspaceTabMetrics.groupSpacing
            )
        }
        drag?.translation = translation
        groupDrag.show(drag)
    }

    private func dropDraggedGroup() {
        guard let drag = groupDrag.drag else { return }
        let stillMatches = drag.itemIDs == store.tabStrip.groupKeysInOrder
        withAnimation(TabBarDragMetrics.slideAnimation) {
            if stillMatches { store.moveTabGroup(drag.draggedID, toPlace: drag.targetIndex) }
            groupDrag.show(nil)
        }
    }

    private func toggleCollapsed(_ projectKey: String) {
        if collapsedProjectKeys.contains(projectKey) {
            expandGroup(projectKey)
            return
        }
        selectTabInSight(insteadOfTabsIn: projectKey)
        withAnimation(ThemeMotion.slide) {
            _ = collapsedProjectKeys.insert(projectKey)
        }
    }

    private func allGroupsCollapsing(_ groupKeys: [String]) -> AllTabGroupsCollapsing {
        let collapsibleKeys = groupKeys.filter { !TerminalSplit.isGroupKeyOfSplitAcrossProjects($0) }
        return AllTabGroupsCollapsing(
            canCollapseAll: collapsibleKeys.contains { !collapsedProjectKeys.contains($0) },
            canExpandAll: !collapsedProjectKeys.isEmpty,
            collapseAll: { withAnimation(ThemeMotion.slide) { collapsedProjectKeys.formUnion(collapsibleKeys) } },
            expandAll: { withAnimation(ThemeMotion.slide) { collapsedProjectKeys.removeAll() } }
        )
    }

    private func revealSelectedTab(_ scrollProxy: ScrollViewProxy) {
        guard let selectedTerminal = store.selectedTerminal else { return }
        let groupKey = store.tabGroupKey(of: selectedTerminal)
        if collapsedProjectKeys.contains(groupKey) {
            expandGroup(groupKey)
        }
        scrollProxy.scrollTo(selectedTerminal.id, anchor: .center)
    }

    private func expandGroup(_ projectKey: String) {
        withAnimation(ThemeMotion.slide) {
            _ = collapsedProjectKeys.remove(projectKey)
        }
    }

    private func selectTabInSight(insteadOfTabsIn projectKey: String) {
        let tabProjectKeys = store.tabGroupKeys
        guard let selectedIndex = store.terminalSessions.firstIndex(where: { $0.id == store.selectedTerminalID }),
            tabProjectKeys[selectedIndex] == projectKey,
            let indexToSelect = TerminalTabOrder.indexToSelect(
                afterCollapsingGroupOfTabAt: selectedIndex,
                collapsedProjectKeys: collapsedProjectKeys,
                amongTabProjectKeys: tabProjectKeys
            )
        else { return }
        store.selectTerminal(store.terminalSessions[indexToSelect].id)
    }
}
