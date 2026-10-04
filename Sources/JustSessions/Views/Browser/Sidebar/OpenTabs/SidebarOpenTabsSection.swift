import SwiftUI

/// The window's open tabs in tab bar order, above the project list and outside its scrolling, so the tab you are on,
/// or any other, stays one click away however far the list is scrolled. The sidebar shows it only while a tab is open.
/// Its heading collapses it; past `maximumVisibleRowCount` tabs, the rows scroll inside it.
struct SidebarOpenTabsSection: View {
    @ObservedObject var store: ConversationStore
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void

    @SceneStorage("isOpenTabsSectionCollapsed") private var isCollapsed = false

    static let maximumVisibleRowCount = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
                .padding(.top, 10)
                .padding(.bottom, 4)
            if !isCollapsed {
                if store.terminalSessions.count <= Self.maximumVisibleRowCount {
                    rows
                } else {
                    // A half row shows at the bottom, so the cut-off reads as a list that scrolls.
                    ScrollView { rows }
                        .frame(height: (CGFloat(Self.maximumVisibleRowCount) + 0.5)
                            * (SidebarOpenTabRow.height + SidebarIndentGuide.rowSpacing))
                }
            }
        }
        .padding(.bottom, 6)
    }

    private var heading: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isCollapsed.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 14)
                Text("Open tabs")
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text(store.terminalSessions.count.formatted())
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(.leading, 18)
            .padding(.trailing, 16)
            .frame(height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCollapsed ? "Expand open tabs" : "Collapse open tabs")
    }

    private var rows: some View {
        VStack(spacing: SidebarIndentGuide.rowSpacing) {
            ForEach(store.terminalSessions) { tab in
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
    }
}
