import SwiftUI

/// One choice of the Appearance setting: the window sketch in that appearance above its name, ringed in ink while
/// chosen and faintly under the pointer.
struct AppAppearanceOption: View {
    let mode: AppAppearanceMode
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private var thumbnailShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }

    private var ringShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
    }

    private var ringColor: Color {
        if isSelected { return ThemePalette.ink }
        return isHovered ? ThemePalette.ink.opacity(0.2) : .clear
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                AppAppearanceThumbnail(mode: mode)
                    .frame(width: 112, height: 72)
                    .clipShape(thumbnailShape)
                    .overlay(thumbnailShape.strokeBorder(ThemePalette.hairline))
                    .padding(3)
                    .overlay(ringShape.strokeBorder(ringColor, lineWidth: 2))
                Text(mode.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(mode.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
