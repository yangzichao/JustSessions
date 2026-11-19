import SwiftUI

struct WorkspaceTabBackground: View {
    let isSelected: Bool
    let isHovered: Bool
    let showsLeadingSeparator: Bool
    let groupColor: ThemeColor
    var splitSide: TerminalSplit.Side?

    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    private static let separatorColor = ThemeColor(role: .line, opacity: 0.18)

    var body: some View {
        ZStack {
            if isSelected {
                WorkspaceTabShape(splitSide: splitSide)
                    .fill(terminalPalette.backgroundColor)
                WorkspaceTabShape(splitSide: splitSide, isOpenAtBottom: true)
                    .stroke(groupColor, style: StrokeStyle(lineWidth: WorkspaceTabMetrics.groupLineWidth, lineCap: .round))
                    .padding(.vertical, WorkspaceTabMetrics.groupLineWidth / 2)
            } else if isHovered {
                WorkspaceTabHoverShape(splitSide: splitSide)
                    .fill(ThemePalette.hoverFill)
            }
        }
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
