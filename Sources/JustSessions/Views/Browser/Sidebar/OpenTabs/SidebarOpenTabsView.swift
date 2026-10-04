import SwiftUI

/// A full-height list in tab-bar order, grouped by project like the tab bar, each group under a heading in its color.
/// It stays mounted beside the project list to retain its scroll position.
struct SidebarOpenTabsView: View {
    @ObservedObject var store: ConversationStore
    let searchText: String
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void
    let onNewSession: () -> Void

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

    var body: some View {
        let tabs = matchingTabs
        let groups = TerminalTabGroup.groups(of: tabs, projectDirectoryKey: \.projectDirectoryKey)
        // Colors come from every open group, as in the tab bar, so a search that hides a group recolors no other.
        let colorsByProjectKey = TabGroupPalette.colorsByProjectKey(
            TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: \.projectDirectoryKey)
                .map(\.projectDirectoryKey)
        )

        ScrollView {
            LazyVStack(spacing: SidebarIndentGuide.rowSpacing) {
                ForEach(groups) { group in
                    let projectName = store.projectDisplayName(forProjectPath: group.projectDirectoryKey)
                    SidebarOpenTabGroupHeading(
                        projectName: projectName,
                        location: ProjectLocation(key: group.projectDirectoryKey),
                        color: colorsByProjectKey[group.projectDirectoryKey] ?? ThemePalette.ink,
                        tabCount: group.tabs.count
                    )
                    .padding(.top, group.id == groups.first?.id ? 0 : Self.groupSpacing)
                    ForEach(group.tabs) { tab in
                        SidebarOpenTabRow(
                            tab: tab,
                            projectDisplayName: projectName,
                            isSelected: store.selectedTerminalID == tab.id,
                            onSelect: { onSelectTab(tab.id) },
                            onClose: { onCloseTab(tab.id) }
                        )
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
    }
}
