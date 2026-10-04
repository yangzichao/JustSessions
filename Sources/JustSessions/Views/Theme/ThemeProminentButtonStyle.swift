import SwiftUI

/// The app's primary action, using the same ink and foreground as the new-session badge.
struct ThemeProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ThemePalette.inkForeground)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(ThemePalette.ink))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .modifier(ThemeButtonPressFeedback(isPressed: configuration.isPressed))
    }
}
