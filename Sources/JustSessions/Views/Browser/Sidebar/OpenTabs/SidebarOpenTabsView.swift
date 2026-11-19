import SwiftUI

struct SidebarOpenTabsView: View {
    let store: ConversationStore
    let searchText: String
    @Binding var selection: OpenTabMultiSelection
    let onSelectTab: (UUID) -> Void
    let onDroppedTabIntoTerminals: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onCloseTab: (UUID) -> Void
    let onDeleteConversation: (Conversation) -> Void
    let onCloseTabGroup: ([UUID], _ projectName: String) -> Void
    let onCloseSelectedTabs: ([UUID]) -> Void
    let onNewSession: () -> Void

    @State var groupCollapse = OpenTabGroupCollapse()
    @FocusState var isListFocused: Bool

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
                                splitOrientation: store.splitViewID(containing: tab.id).map(store.orientation(ofSplitView:)) ?? .sideBySide,
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
