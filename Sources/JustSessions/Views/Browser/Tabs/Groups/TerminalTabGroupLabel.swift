import SwiftUI

/// The project's name in its group color, in front of its tabs. Clicking it collapses or expands the group. A
/// collapsed group counts its hidden tabs and shows the most pressing status among them, so a CLI waiting on you
/// still shows.
struct TerminalTabGroupLabel: View {
    let projectName: String
    let location: ProjectLocation
    let color: Color
    let tabCount: Int
    let isCollapsed: Bool
    let hiddenTabCount: Int
    let hiddenTabsActivity: SessionActivitySummary
    let onToggleCollapsed: () -> Void

    @State private var isHovered = false

    private var labelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }

    var body: some View {
        Button(action: onToggleCollapsed) {
            HStack(spacing: 5) {
                if location.host != .thisMac {
                    Image(systemName: location.host.symbolName)
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(projectName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 140)
                if isCollapsed && hiddenTabCount > 0 {
                    Text("\(hiddenTabCount)")
                        .monospacedDigit()
                        .opacity(0.75)
                    if let status = hiddenTabsActivity.mostPressingStatus {
                        SessionStatusIndicator(status: status, description: hiddenTabsActivity.summary)
                    }
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(labelShape.fill(color.opacity(isHovered ? 0.24 : 0.15)))
            .contentShape(labelShape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(isCollapsed ? "Expand" : "Collapse") \(projectName) — \(location.copyablePath)")
        .accessibilityLabel("\(projectName) tab group")
        .accessibilityValue("\(isCollapsed ? "Collapsed" : "Expanded"), \(CountedNoun.phrase(count: tabCount, singular: "tab"))")
        .contextMenu {
            Button(isCollapsed ? "Expand Group" : "Collapse Group", systemImage: isCollapsed ? "chevron.right" : "chevron.left", action: onToggleCollapsed)
        }
    }
}
