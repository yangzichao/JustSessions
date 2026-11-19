import SwiftUI

struct NotificationBellList: View {
    let entries: [NotificationBellEntry]
    let onShow: (NotificationBellEntry) -> Void

    private static var width: CGFloat { InterfaceScale.points(300) }
    private static let rowSpacing: CGFloat = 2
    private static var maximumRowsHeight: CGFloat { InterfaceScale.points(360) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Waiting for you")
                .font(ThemeFont.heading)
                .padding(.horizontal, 8)
            if entries.isEmpty {
                Text("No Claude Code, Codex, Antigravity, Pi, or OpenCode session is waiting for you")
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            } else {
                ScrollView {
                    VStack(spacing: Self.rowSpacing) {
                        ForEach(entries) { entry in
                            NotificationBellRow(entry: entry) { onShow(entry) }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: rowsHeight)
            }
        }
        .foregroundStyle(ThemePalette.ink)
        .frame(width: Self.width, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(ThemePalette.contentSurface)
    }

    /// A popover takes its content's size, so the scroll view is given the rows' height, up to its maximum.
    private var rowsHeight: CGFloat {
        let count = CGFloat(entries.count)
        return min(count * NotificationBellRow.height + (count - 1) * Self.rowSpacing, Self.maximumRowsHeight)
    }
}
