import SwiftUI

/// A full-height list in tab-bar order, grouped by project like the tab bar, each group under a heading in its color
/// that collapses it. It stays mounted beside the project list to retain its scroll position and collapsed groups.
/// Each tab of a split across projects lists under its own project, marked with its side of the split, as is each
/// tab of a split in its project's group. Rows, headings, and the space around them offer the menus of the tab bar's
/// tabs, group labels, and space. A row drags onto the terminals as its tab would from the tab bar. ⌘- and Shift-clicks
/// select several rows to close together; see `SidebarOpenTabsView+Selection`.
struct SidebarOpenTabsView: View {
    let store: ConversationStore
    let searchText: String
    @Binding var selection: OpenTabMultiSelection
    let onSelectTab: (UUID) -> Void
    /// Called once a tab dragged onto the terminals shows there.
    let onDroppedTabIntoTerminals: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void
    let onDeleteConversation: (Conversation) -> Void
    /// Closes a group's tabs, asking once for them all.
    let onCloseTabGroup: ([UUID], _ projectName: String) -> Void
    /// Closes the selected tabs, asking once for them all.
    let onCloseSelectedTabs: ([UUID]) -> Void
    let onNewSession: () -> Void

    @State var groupCollapse = OpenTabGroupCollapse()
    /// Set by a ⌘- or Shift-click, so Escape cancels the selection; see `SidebarSelectionScrollView`.
    @FocusState var isListFocused: Bool

    /// Space above each group's heading after the first, which sets the groups apart without indenting their rows.
    static let groupSpacing: CGFloat = 10

    var matchingTabs: [TerminalSession] {
        store.terminalSessions.filter { tab in
            SidebarOpenTabSearch.matches(
                searchText,
                title: tab.displayTitle,
                projectName: store.projectDisplayName(forProjectPath: tab.projectDirectoryKey),
                projectPath: tab.projectPath,
                host: tab.host
            )
        }
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let tabs = matchingTabs
        let groups = TerminalTabGroup.groups(of: tabs, projectDirectoryKey: \.projectDirectoryKey)
        // Colors come from every open tab's project, as in the tab bar, so a search that hides a group recolors no other.
        let colorsByProjectKey = TabGroupPalette.colorsByProjectKey(store.tabProjectKeysInOrder)
        let allGroups = allGroupsCollapsing(groups.map(\.projectDirectoryKey))

        SidebarSelectionScrollView(isFocused: $isListFocused, onDismissSelection: { selection.clear() }) {
            LazyVStack(spacing: SidebarIndentGuide.rowSpacing) {
                ForEach(groups) { group in
                    let projectName = store.projectDisplayName(forProjectPath: group.projectDirectoryKey)
                    let isCollapsed = groupCollapse.isCollapsed(group.projectDirectoryKey, whileSearching: isSearching)
                    SidebarOpenTabGroupHeading(
                        store: store,
                        projectName: projectName,
                        location: ProjectLocation(key: group.projectDirectoryKey),
                        color: colorsByProjectKey[group.projectDirectoryKey] ?? ThemePalette.ink,
                        tabCount: group.tabs.count,
                        isCollapsed: isCollapsed,
                        hiddenTabsActivity: isCollapsed ? SessionActivitySummary(tabs: group.tabs) : SessionActivitySummary(activities: []),
                        onToggleCollapsed: { groupCollapse.toggle(group.projectDirectoryKey) },
                        onNewSession: { provider in
                            store.launchNewSessionFromProject(provider: provider, projectPath: group.projectDirectoryKey)
                        },
                        menuItems: TabGroupMenuItems(
                            store: store,
                            projectKey: group.projectDirectoryKey,
                            projectDisplayName: projectName,
                            isCollapsed: isCollapsed,
                            onToggleCollapsed: { groupCollapse.toggle(group.projectDirectoryKey) },
                            allGroups: allGroups,
                            onCloseTabs: { onCloseTabGroup(group.tabs.map(\.id), projectName) }
                        )
                    )
                    .padding(.top, group.id == groups.first?.id ? 0 : Self.groupSpacing)
                    if !isCollapsed {
                        ForEach(group.tabs) { tab in
                            SidebarOpenTabRow(
                                tab: tab,
                                projectDisplayName: store.projectDisplayName(forProjectPath: tab.projectDirectoryKey),
                                splitSide: store.split(containing: tab.id).flatMap { store.sides(of: $0)?.side(of: tab.id) }
                                    ?? store.splitChooser(beside: tab.id)?.tabSide,
                                splitOrientation: (store.split(containing: tab.id)?.id ?? store.splitChooser(beside: tab.id)?.id)
                                    .map(store.orientation(ofSplitView:)) ?? .sideBySide,
                                isSelected: isHighlighted(tab.id),
                                onSelect: { handleRowClick(tab.id) }
                            ) {
                                if selection.hasMultipleSelected && selection.contains(tab.id) {
                                    SelectedOpenTabsContextMenu(
                                        selectedTabCount: selection.selectedTabIDs.count,
                                        onClose: { onCloseSelectedTabs(Array(selection.selectedTabIDs)) }
                                    )
                                } else {
                                    TerminalTabMenuItems(
                                        store: store, tab: tab, onRename: onRenameConversation, onCloseTab: onCloseTab,
                                        onDelete: onDeleteConversation
                                    )
                                }
                            }
                            .sidebarRowDragIntoSplit(
                                .openTab(tab.id),
                                titled: tab.displayTitle,
                                in: store,
                                fadesWhileDragged: true,
                                onDropped: onDroppedTabIntoTerminals
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        // Rows and headings have menus of their own, which a right-click on them shows instead.
        .contextMenu { TabGroupsBackgroundMenuItems(onNewSession: onNewSession, allGroups: allGroups) }
        .overlay {
            if tabs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(ThemeFont.glyph(.emptyState))
                        .foregroundStyle(ThemePalette.tertiaryText)
                    if store.terminalSessions.isEmpty {
                        Text("No open tabs")
                        Button("New session", action: onNewSession)
                            .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 6, verticalPadding: 4))
                    } else {
                        Text("No matching open tabs")
                    }
                }
                .font(ThemeFont.callout)
                .foregroundStyle(ThemePalette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(16)
            }
        }
        .accessibilityIdentifier("sidebar.openTabs")
        .onChange(of: store.selectedTerminalID) { _, _ in
            // A tab selected from the tab bar or by shortcut shows its row, as selecting one there expands its group,
            // and its row is the one highlighted, in place of any rows selected to close.
            expandSelectedTabsGroup()
            selection.clear()
        }
        .onChange(of: store.tabProjectKeysInOrder) { _, openProjectKeys in
            groupCollapse.keepOnly(openProjectKeys)
        }
        .onChange(of: tabs.map(\.id)) { _, listedTabIDs in
            selection.keepOnly(Set(listedTabIDs))
        }
    }

    /// A search shows every group expanded, but these still collapse and expand the groups it leaves for afterwards.
    private func allGroupsCollapsing(_ groupKeys: [String]) -> AllTabGroupsCollapsing {
        AllTabGroupsCollapsing(
            canCollapseAll: groupKeys.contains { !groupCollapse.collapsedProjectKeys.contains($0) },
            canExpandAll: !groupCollapse.collapsedProjectKeys.isEmpty,
            collapseAll: { groupCollapse.collapse(groupKeys) },
            expandAll: { groupCollapse.expandAll() }
        )
    }

    private func expandSelectedTabsGroup() {
        guard let selectedTerminal = store.selectedTerminal else { return }
        groupCollapse.expand(selectedTerminal.projectDirectoryKey)
    }
}
