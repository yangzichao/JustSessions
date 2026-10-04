import SwiftUI

/// A project's name above its open tabs, in its tab bar group's color, with its SSH host and its tab count. Clicking it
/// collapses or expands the group, as a project's chevron does in Projects; a collapsed group shows the most pressing
/// status among its tabs, so a CLI waiting on you still shows. It lines up with the rows below instead of indenting
/// them: its chevron sits in their icon column and its name starts where their titles do, so the rows keep the
/// sidebar's full width.
struct SidebarOpenTabGroupHeading: View {
    let projectName: String
    let location: ProjectLocation
    let color: ThemeColor
    let tabCount: Int
    let isCollapsed: Bool
    /// What the collapsed group's CLIs are doing. Ignored while the group is expanded, as each row shows its own.
    let hiddenTabsActivity: SessionActivitySummary
    let onToggleCollapsed: () -> Void

    static let height: CGFloat = 24

    var body: some View {
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
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                Spacer(minLength: 6)
                if isCollapsed, let status = hiddenTabsActivity.mostPressingStatus {
                    SessionStatusIndicator(status: status, description: hiddenTabsActivity.summary)
                }
                Text(verbatim: "\(tabCount)")
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .frame(height: Self.height)
            .contentShape(Rectangle())
            .sidebarRowHighlight(isSelected: false)
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .help("\(isCollapsed ? "Expand" : "Collapse") \(projectName) — \(location.copyablePath)")
        .accessibilityLabel("\(projectName) tab group")
        .accessibilityValue("\(isCollapsed ? "Collapsed" : "Expanded"), \(CountedNoun.phrase(count: tabCount, singular: "tab"))")
        .accessibilityAddTraits(.isHeader)
    }
}
