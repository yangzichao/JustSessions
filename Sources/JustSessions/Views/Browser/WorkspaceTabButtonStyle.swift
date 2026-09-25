import SwiftUI

/// Chip look shared by the Preview tab and terminal tabs. The selected tab is a raised paper chip with ink text,
/// like a tab pulled forward; the others sit flat in secondary text and only show a faint fill under the pointer.
struct WorkspaceTabButtonStyle: ButtonStyle {
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
            .foregroundStyle(isSelected ? ThemePalette.ink : Color.secondary)
            .padding(.horizontal, 11)
            .frame(height: 28)
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
