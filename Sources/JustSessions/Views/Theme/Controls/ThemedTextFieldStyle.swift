import SwiftUI

struct ThemedTextFieldStyle: TextFieldStyle {
    // periphery:ignore - the TextFieldStyle requirement SwiftUI calls.
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .themedTextFieldSurface()
    }
}

extension View {
    nonisolated func themedTextFieldSurface() -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(ThemePalette.raisedSurface, in: RoundedRectangle(.control))
            .overlay(RoundedRectangle(.control).strokeBorder(ThemePalette.hairline))
    }
}
