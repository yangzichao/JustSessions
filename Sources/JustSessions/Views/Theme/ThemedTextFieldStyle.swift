import SwiftUI

/// The same raised surface as search fields and other app controls, including in secondary windows and sheets.
struct ThemedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .themedTextFieldSurface()
    }
}

extension View {
    /// A themed text field's padding, surface, and outline, also for text shown in place of a field, such as a
    /// locked one.
    nonisolated func themedTextFieldSurface() -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ThemePalette.hairline))
    }
}
