import SwiftUI

struct SidebarOpenTabGroupHeading: View {
    let store: ConversationStore
    let projectName: String
    let location: ProjectLocation
    let color: ThemeColor
    let tabCount: Int
    let isCollapsed: Bool
    let hiddenTabsActivity: SessionActivitySummary
    let onToggleCollapsed: () -> Void
    let onNewSession: (ConversationProvider) -> Void
    let menuItems: TabGroupMenuItems

    @State private var isHovered = false
    var isHoveredForTests: Bool? = nil
    private var hovered: Bool { isHoveredForTests ?? isHovered }

    static var height: CGFloat { InterfaceScale.points(24) }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggleCollapsed) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(ThemeFont.glyph(.small, weight: .bold))
                        .foregroundStyle(color)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .animation(ThemeMotion.disclosure, value: isCollapsed)
                        .frame(width: InterfaceScale.points(14))
                    HStack(spacing: 5) {
                        Text(verbatim: projectName)
                            .foregroundStyle(color)
                            .layoutPriority(1)
                        if let destination = location.host.sshDestination {
                            Image(systemName: location.host.symbolName)
                                .font(ThemeFont.glyph(.small, weight: .semibold))
                            Text(verbatim: destination)
                        }
                    }
                    .foregroundStyle(ThemePalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    Spacer(minLength: 6)
                    if isCollapsed, let status = hiddenTabsActivity.mostPressingStatus {
                        SessionStatusIndicator(status: status, description: hiddenTabsActivity.summary)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .frame(height: Self.height)
                .contentShape(Rectangle())
            }
            .buttonStyle(ThemePlainButtonStyle(showsHover: false))
            .help("\(isCollapsed ? "Expand" : "Collapse") \(projectName) — \(location.copyablePath)")
            .accessibilityLabel("\(projectName) tab group")
            .accessibilityValue("\(isCollapsed ? "Collapsed" : "Expanded"), \(CountedNoun.phrase(count: tabCount, singular: "tab"))")
            .accessibilityAddTraits(.isHeader)

            tabCountOrHoverActions
                .padding(.trailing, 10)
        }
        .font(ThemeFont.detail.weight(.semibold))
        .background(SidebarRowBackground(isSelected: false, isHovered: hovered))
        .onHover { isHovered = $0 }
        .contextMenu { menuItems }
    }

    private var tabCountOrHoverActions: some View {
        ZStack(alignment: .trailing) {
            Text(verbatim: "\(tabCount)")
                .monospacedDigit()
                .foregroundStyle(ThemePalette.tertiaryText)
                .opacity(hovered ? 0 : 1)
            ProjectHoverActions<EmptyView>.placeholder
                .font(ThemeFont.body)
        }
        .overlay(alignment: .trailing) {
            if hovered {
                ProjectHoverActions(store: store, location: location, projectDisplayName: projectName, onNewSession: onNewSession) {
                    menuItems
                }
                .font(ThemeFont.body)
            }
        }
    }
}
