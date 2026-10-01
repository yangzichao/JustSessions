import SwiftUI

/// The open tabs, grouped by project like tab groups in a browser: each project's tabs sit together behind a label
/// in the project's color, which collapses or expands the group.
struct WorkspaceTabBar: View {
    @ObservedObject var store: ConversationStore
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
                .padding(.vertical, 8)
            }
            .onChange(of: store.selectedTerminalID) { _, selectedTerminalID in
                if let selectedTerminalID {
                    scrollProxy.scrollTo(selectedTerminalID, anchor: .center)
                }
            }
        }
        .background(ThemePalette.contentSurface)
        .onChange(of: groups.map(\.projectDirectoryKey)) { _, openProjectKeys in
            // A project whose last tab closed opens expanded next time.
            collapsedProjectKeys.formIntersection(openProjectKeys)
        }
    }

    private func toggleCollapsed(_ projectKey: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            if collapsedProjectKeys.contains(projectKey) {
                collapsedProjectKeys.remove(projectKey)
            } else {
                collapsedProjectKeys.insert(projectKey)
            }
        }
    }
}
