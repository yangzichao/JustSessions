import SwiftUI

/// A secondary button: a raised surface with a hairline, next to a `ProviderProminentButtonStyle` button.
struct QuietBorderedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private var isCompact: Bool { controlSize == .mini || controlSize == .small }
    private var cornerRadius: CGFloat { isCompact ? 6 : 8 }
    private var height: CGFloat { isCompact ? 22 : 28 }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isCompact ? 11 : 12, weight: .medium))
            .foregroundStyle(ThemePalette.ink)
            .padding(.horizontal, isCompact ? 10 : 12)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ThemePalette.raisedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ThemePalette.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if isEnabled && configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(ThemePalette.pressedFill)
                        .allowsHitTesting(false)
                }
            }
            .modifier(ThemeButtonPressFeedback(isPressed: configuration.isPressed))
    }
}
