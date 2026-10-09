import SwiftUI

/// A project's name above its open tabs, in its tab bar group's color, with its SSH host and its tab count. Clicking it
/// collapses or expands the group, as a project's chevron does in Projects; a collapsed group shows the most pressing
/// status among its tabs, so a CLI waiting on you still shows. It lines up with the rows below instead of indenting
/// them: its chevron sits in their icon column and its name starts where their titles do, so the rows keep the
/// sidebar's full width. As a project row does, it trades its count for ⋯ and + while the pointer is over it, and its
/// menu offers what a project row's does for the folder, leaving out what arranges projects in the sidebar.
struct SidebarOpenTabGroupHeading: View {
    @ObservedObject var store: ConversationStore
    let projectName: String
    let location: ProjectLocation
    let color: ThemeColor
    let tabCount: Int
    let isCollapsed: Bool
    /// What the collapsed group's CLIs are doing. Ignored while the group is expanded, as each row shows its own.
    let hiddenTabsActivity: SessionActivitySummary
    let onToggleCollapsed: () -> Void
    let onNewSession: (ConversationProvider) -> Void

    @State private var isHovered = false

    static let height: CGFloat = 24

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggleCollapsed) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(color)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .animation(.easeOut(duration: 0.12), value: isCollapsed)
                        .frame(width: 14)
                    HStack(spacing: 5) {
                        Text(verbatim: projectName)
                            .foregroundStyle(color)
                            .layoutPriority(1)
                        if let destination = location.host.sshDestination {
                            Image(systemName: location.host.symbolName)
                                .font(.system(size: 9, weight: .semibold))
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
        .font(.system(size: 11, weight: .semibold))
        .background(SidebarRowBackground(isSelected: false, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .contextMenu { menuItems }
    }

    /// The same items whether the menu comes from a right-click or the ⋯ button.
    private var menuItems: some View {
        ProjectFolderMenuItems(store: store, location: location, projectDisplayName: projectName, onNewSession: onNewSession)
    }

    /// The tab count gives way to the ⋯ and + menus while the pointer is over the heading. Both keep their room while
    /// hidden, so nothing in the heading moves as the pointer passes over it.
    private var tabCountOrHoverActions: some View {
        ZStack(alignment: .trailing) {
            Text(verbatim: "\(tabCount)")
                .monospacedDigit()
                .foregroundStyle(ThemePalette.tertiaryText)
                .opacity(isHovered ? 0 : 1)
            ProjectHoverActions(store: store, location: location, projectDisplayName: projectName, onNewSession: onNewSession) {
                menuItems
            }
            .font(.system(size: 13))
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
        }
    }
}
