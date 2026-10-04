import SwiftUI

/// The open tabs, grouped by project like tab groups in a browser: each project's tabs sit together behind a label
/// in the project's color, which collapses or expands the group. Selecting a tab of a collapsed group, by shortcut or
/// from the sidebar, expands it. The bar sits in the title bar, in the sidebar's color, like a browser's tab strip:
/// the selected tab takes its terminal's color and runs down into it, through the bar's bottom line.
struct WorkspaceTabBar: View {
    @ObservedObject var store: ConversationStore
    /// Width at the leading edge that tabs never enter, even when scrolled, so the window buttons and sidebar toggle
    /// stay clear of them.
    let leadingClearance: CGFloat
    let onRenameConversation: (Conversation) -> Void
    let onCloseTerminal: (UUID) -> Void
    @State private var collapsedProjectKeys: Set<String> = []

    var body: some View {
        let groups = TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: \.projectDirectoryKey)
        let colorsByProjectKey = TabGroupPalette.colorsByProjectKey(groups.map(\.projectDirectoryKey))
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(groups) { group in
                        TerminalTabGroupSection(
                            store: store,
                            group: group,
                            color: colorsByProjectKey[group.projectDirectoryKey] ?? ThemePalette.ink,
                            isCollapsed: collapsedProjectKeys.contains(group.projectDirectoryKey),
                            onToggleCollapsed: { toggleCollapsed(group.projectDirectoryKey) },
                            onRenameConversation: onRenameConversation,
                            onCloseTab: onCloseTerminal
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, WorkspaceTabMetrics.topInset)
            }
            .onChange(of: store.selectedTerminalID) { _, selectedTerminalID in
                guard let selectedTerminal = store.selectedTerminal else { return }
                if collapsedProjectKeys.contains(selectedTerminal.projectDirectoryKey) {
                    expandGroup(selectedTerminal.projectDirectoryKey)
                }
                scrollProxy.scrollTo(selectedTerminalID, anchor: .center)
            }
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

    private func expandGroup(_ projectKey: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            _ = collapsedProjectKeys.remove(projectKey)
        }
    }

    /// With every other tab in a collapsed group too, the selected tab keeps showing behind its collapsed label.
    private func selectTabInSight(insteadOfTabsIn projectKey: String) {
        let tabProjectKeys = store.terminalSessions.map(\.projectDirectoryKey)
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
