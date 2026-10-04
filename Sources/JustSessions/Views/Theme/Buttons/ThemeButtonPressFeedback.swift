import SwiftUI

/// Filled controls and thumbnails dim and depress slightly without changing their layout.
struct ThemeButtonPressFeedback: ViewModifier {
    let isPressed: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isEnabled ? (isPressed ? 0.75 : 1) : 0.4)
            .scaleEffect(isEnabled && isPressed && !reduceMotion ? 0.97 : 1)
    }
}

/// Preserves a label's existing hover and selection design while adding feedback during a press.
struct ThemePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(ThemeButtonPressFeedback(isPressed: configuration.isPressed))
    }
}
