import SwiftUI

struct ThemeProminentButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize

    private var isCompact: Bool { controlSize == .mini || controlSize == .small }
    private var shape: RoundedRectangle { RoundedRectangle(isCompact ? .control : .card) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font((isCompact ? ThemeFont.detail : ThemeFont.callout).weight(.semibold))
            .foregroundStyle(ThemePalette.inkForeground)
            .padding(.horizontal, isCompact ? 10 : 14)
            .frame(height: isCompact ? 22 : 28)
            .background(shape.fill(ThemePalette.ink))
            .contentShape(shape)
            .modifier(ThemeButtonPressFeedback(isPressed: configuration.isPressed))
    }
}
