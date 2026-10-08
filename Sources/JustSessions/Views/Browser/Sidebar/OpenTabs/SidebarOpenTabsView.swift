import SwiftUI

/// A full-height list in tab-bar order, grouped by project like the tab bar, each group under a heading in its color
/// that collapses it. It stays mounted beside the project list to retain its scroll position and collapsed groups.
/// A split's tab from another project lists in the group it shows in on the tab bar, still named for its own project.
struct SidebarOpenTabsView: View {
    @ObservedObject var store: ConversationStore
    let searchText: String
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void
    let onNewSession: () -> Void

    @State private var groupCollapse = OpenTabGroupCollapse()

    /// Space above each group's heading after the first, which sets the groups apart without indenting their rows.
    static let groupSpacing: CGFloat = 10

    private var matchingTabs: [TerminalSession] {
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

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let tabs = matchingTabs
        let groups = TerminalTabGroup.groups(of: tabs, projectDirectoryKey: store.tabGroupKey(of:))
        // Colors come from every open group, as in the tab bar, so a search that hides a group recolors no other.
        let colorsByProjectKey = TabGroupPalette.colorsByProjectKey(
            TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: store.tabGroupKey(of:))
                .map(\.projectDirectoryKey)
        )

        ScrollView {
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
                        }
                    )
                    .padding(.top, group.id == groups.first?.id ? 0 : Self.groupSpacing)
                    if !isCollapsed {
                        ForEach(group.tabs) { tab in
                            SidebarOpenTabRow(
                                tab: tab,
                                projectDisplayName: store.projectDisplayName(forProjectPath: tab.projectDirectoryKey),
                                isSelected: store.selectedTerminalID == tab.id,
                                onSelect: { onSelectTab(tab.id) },
                                onClose: { onCloseTab(tab.id) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .overlay {
            if tabs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    if store.terminalSessions.isEmpty {
                        Text("No open tabs")
                        Button("New session", action: onNewSession)
                            .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 6, verticalPadding: 4))
                    } else {
                        Text("No matching open tabs")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(16)
            }
        }
        .accessibilityIdentifier("sidebar.openTabs")
        .onChange(of: store.selectedTerminalID) { _, _ in
            // A tab selected from the tab bar or by shortcut shows its row, as selecting one there expands its group.
            expandSelectedTabsGroup()
        }
        .onChange(of: store.selectedTerminal.map(store.tabGroupKey(of:))) { _, _ in
            // So does the selected tab moving into a collapsed group, as when it leaves a split in another's group.
            expandSelectedTabsGroup()
        }
        .onChange(of: store.tabGroupKeys) { _, openGroupKeys in
            groupCollapse.keepOnly(openGroupKeys)
        }
    }

    private func expandSelectedTabsGroup() {
        guard let selectedTerminal = store.selectedTerminal else { return }
        groupCollapse.expand(store.tabGroupKey(of: selectedTerminal))
    }
}
