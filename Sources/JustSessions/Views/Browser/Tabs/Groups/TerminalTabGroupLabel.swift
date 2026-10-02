import AppKit
import SwiftUI

/// The project's name in its group color, in front of its tabs. Clicking it collapses or expands the group. A
/// collapsed group counts its hidden tabs and shows the most pressing status among them, so a CLI waiting on you
/// still shows.
struct TerminalTabGroupLabel: View {
    let projectName: String
    let location: ProjectLocation
    let color: ThemeColor
    let tabCount: Int
    let isCollapsed: Bool
    /// False while the group's only tab is the selected one, which a collapsed group keeps in sight anyway.
    let canCollapse: Bool
    let hiddenTabCount: Int
    let hiddenTabsActivity: SessionActivitySummary
    let onToggleCollapsed: () -> Void

    @State private var isHovered = false

    private var labelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }

    /// A click that would change nothing on screen leaves the group as it is, so it does not hide the tab later.
    private var canToggle: Bool {
        isCollapsed || canCollapse
    }

    var body: some View {
        Button(action: toggleOnFirstClick) {
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
            .background(labelShape.fill(color.opacity(isHovered && canToggle ? 0.24 : 0.15)))
            // The click target runs the full height of the tabs beside it, not just the pill.
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(canToggle ? "\(isCollapsed ? "Expand" : "Collapse") \(projectName) — \(location.copyablePath)" : location.copyablePath)
        .accessibilityLabel("\(projectName) tab group")
        .accessibilityValue("\(isCollapsed ? "Collapsed" : "Expanded"), \(CountedNoun.phrase(count: tabCount, singular: "tab"))")
        .contextMenu {
            Button(isCollapsed ? "Expand Group" : "Collapse Group", systemImage: isCollapsed ? "chevron.right" : "chevron.left", action: onToggleCollapsed)
                .disabled(!canToggle)
        }
    }

    /// A double-click counts as one click. Its second click would otherwise open the group right back up.
    private func toggleOnFirstClick() {
        guard canToggle else { return }
        if let event = NSApp.currentEvent, event.type == .leftMouseUp, event.clickCount > 1 { return }
        onToggleCollapsed()
    }
}
