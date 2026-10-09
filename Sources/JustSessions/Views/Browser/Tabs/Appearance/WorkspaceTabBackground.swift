import SwiftUI

/// What sits behind a tab. The selected tab is filled with its terminal's background and outlined in its group's color,
/// as Chrome outlines the active tab of a group: the outline rises from the group's underline and runs back down into
/// it, as thick as the underline, so the two read as one line. Another tab shows a faint fill under the pointer, and a
/// short line parts it from the tab before. A split's two tabs draw one joined shape, selected or under the pointer,
/// its outline running only along the joined shape's outer edge.
struct WorkspaceTabBackground: View {
    let isSelected: Bool
    let isHovered: Bool
    let showsLeadingSeparator: Bool
    /// The color of the tab's group, which its underline and the selected tab's outline share.
    let groupColor: ThemeColor
    /// The tab's side of its split, or nil for a tab in no split.
    var splitSide: TerminalSplit.Side?

    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    private static let separatorColor = ThemeColor(role: .line, opacity: 0.18)

    var body: some View {
        ZStack {
            if isSelected {
                WorkspaceTabShape(splitSide: splitSide)
                    .fill(terminalPalette.backgroundColor)
                // Inset half the stroke so the feet end on the center of the group's underline. Round ends, like the
                // underline's, where a foot reaches past the group's last tab.
                WorkspaceTabShape(splitSide: splitSide, isOpenAtBottom: true)
                    .stroke(groupColor, style: StrokeStyle(lineWidth: WorkspaceTabMetrics.groupLineWidth, lineCap: .round))
                    .padding(.vertical, WorkspaceTabMetrics.groupLineWidth / 2)
            } else if isHovered {
                WorkspaceTabHoverShape(splitSide: splitSide)
                    .fill(ThemePalette.hoverFill)
            }
        }
        // Spans the tab even with nothing drawn, so the separator lands on the tab's leading edge.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .leading) {
            if showsLeadingSeparator {
                Rectangle()
                    .fill(Self.separatorColor)
                    .frame(width: 1, height: 16)
                    .offset(x: -0.5)
            }
        }
    }
}
