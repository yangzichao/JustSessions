import SwiftUI

/// A full-height list in tab-bar order. It stays mounted beside the project list to retain its scroll position.
struct SidebarOpenTabsView: View {
    @ObservedObject var store: ConversationStore
    let searchText: String
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void
    let onNewSession: () -> Void

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

        ScrollView {
            LazyVStack(spacing: SidebarIndentGuide.rowSpacing) {
                ForEach(tabs) { tab in
                    SidebarOpenTabRow(
                        tab: tab,
                        projectDisplayName: store.projectDisplayName(forProjectPath: tab.projectDirectoryKey),
                        isSelected: store.selectedTerminalID == tab.id,
                        onSelect: { onSelectTab(tab.id) },
                        onClose: { onCloseTab(tab.id) }
                    )
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
