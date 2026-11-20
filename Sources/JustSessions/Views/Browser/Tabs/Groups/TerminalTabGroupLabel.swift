import AppKit
import SwiftUI

struct TerminalTabGroupLabel: View {
    let projectName: String
    let location: ProjectLocation
    let color: ThemeColor
    let tabCount: Int
    let isCollapsed: Bool
    let hiddenTabCount: Int
    let hiddenTabsActivity: SessionActivitySummary
    let onToggleCollapsed: () -> Void
    let menuItems: TabGroupMenuItems

    @State private var isHovered = false

    private var labelShape: RoundedRectangle {
        RoundedRectangle(.control)
    }

    var body: some View {
        Button(action: toggleCollapsedUnlessThisIsADoubleClicksSecondClick) {
            HStack(spacing: 5) {
                if location.host != .thisMac {
                    Image(systemName: location.host.symbolName)
                        .font(ThemeFont.glyph(.small, weight: .semibold))
                }
                Text(projectName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: InterfaceScale.points(140))
                if isCollapsed && hiddenTabCount > 0 {
                    Text("\(hiddenTabCount)")
                        .monospacedDigit()
                    if let status = hiddenTabsActivity.mostPressingStatus {
                        SessionStatusIndicator(status: status, description: hiddenTabsActivity.summary)
                    }
                }
            }
            .font(ThemeFont.detail.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(height: WorkspaceTabMetrics.height - 8)
            .background(labelShape.fill(OpaqueWash(surface: ThemePalette.sidebarSurface, wash: color, opacity: isHovered ? 0.24 : 0.15)))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(ThemePressButtonStyle())
        .onHover { isHovered = $0 }
        .accessibilityHint(Text(verbatim: location.copyablePath))
        .accessibilityLabel("\(projectName) tab group")
        .accessibilityValue("\(isCollapsed ? "Collapsed" : "Expanded"), \(CountedNoun.phrase(count: tabCount, singular: "tab"))")
        .contextMenu { menuItems }
    }

    private func toggleCollapsedUnlessThisIsADoubleClicksSecondClick() {
        if isTheSecondClickOfADoubleClick { return }
        onToggleCollapsed()
    }

    private var isTheSecondClickOfADoubleClick: Bool {
        guard let mouseUpThatPressedTheButton = NSApp.currentEvent, mouseUpThatPressedTheButton.type == .leftMouseUp else { return false }
        return mouseUpThatPressedTheButton.clickCount > 1
    }
}
