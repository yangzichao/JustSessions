import SwiftUI

/// What sits behind a tab. The selected tab is filled with its terminal's background and edged with a hairline that
/// rises from the tab bar's bottom line and runs back down into it. Another tab shows a faint fill under the pointer,
/// and a short line parts it from the tab before.
struct WorkspaceTabBackground: View {
    let isSelected: Bool
    let isHovered: Bool
    let showsLeadingSeparator: Bool

    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    private static let separatorColor = ThemeColor(role: .line, opacity: 0.18)

    var body: some View {
        ZStack {
            if isSelected {
                WorkspaceTabShape()
                    .fill(Color(nsColor: NSColor(hexValue: terminalPalette.background)))
                // Inset half a point so the feet end on the center of the bar's one-point bottom line.
                WorkspaceTabShape(isOpenAtBottom: true)
                    .stroke(ThemePalette.hairline, lineWidth: 1)
                    .padding(.vertical, 0.5)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ThemePalette.hoverFill)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
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
