import SwiftUI

/// Chip look for terminal tabs. The selected tab is a raised chip with ink text,
/// like a tab pulled forward; the others sit flat in secondary text and only show a faint fill under the pointer.
struct WorkspaceTabButtonStyle: ButtonStyle {
    /// Short enough for the tab bar to share the title bar with the window buttons.
    static let height: CGFloat = 24

    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        WorkspaceTabChip(configuration: configuration, isSelected: isSelected)
    }
}

private struct WorkspaceTabChip: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @State private var isHovered = false

    private var chipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? AnyShapeStyle(ThemePalette.ink) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 11)
            .frame(height: WorkspaceTabButtonStyle.height)
            .background {
                if isSelected {
                    chipShape
                        .fill(ThemePalette.raisedSurface)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        .overlay(chipShape.strokeBorder(ThemePalette.hairline))
                } else if isHovered || configuration.isPressed {
                    chipShape.fill(ThemePalette.hoverFill)
                }
            }
            .contentShape(chipShape)
            .onHover { isHovered = $0 }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
