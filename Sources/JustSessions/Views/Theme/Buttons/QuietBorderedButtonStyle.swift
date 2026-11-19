import SwiftUI

struct QuietBorderedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private var isCompact: Bool { controlSize == .mini || controlSize == .small }
    private var shape: RoundedRectangle { RoundedRectangle(isCompact ? .control : .card) }
    private var height: CGFloat { isCompact ? 22 : 28 }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font((isCompact ? ThemeFont.detail : ThemeFont.callout).weight(.medium))
            .foregroundStyle(configuration.role == .destructive ? ThemePalette.errorText : ThemePalette.ink)
            .padding(.horizontal, isCompact ? 10 : 12)
            .frame(height: height)
            .background(shape.fill(ThemePalette.raisedSurface))
            .overlay(shape.strokeBorder(ThemePalette.hairline))
            .contentShape(shape)
            .overlay {
                if isEnabled && configuration.isPressed {
                    shape.fill(ThemePalette.pressedFill).allowsHitTesting(false)
                }
            }
            .modifier(ThemeButtonPressFeedback(isPressed: configuration.isPressed))
    }
}
