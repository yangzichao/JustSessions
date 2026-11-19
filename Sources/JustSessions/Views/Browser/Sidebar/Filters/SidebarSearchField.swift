import SwiftUI

struct SidebarSearchField: View {
    @Binding var text: String
    let placeholder: LocalizedStringKey
    let accessibilityLabel: LocalizedStringKey
    let onClose: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ThemePalette.secondaryText)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onExitCommand(perform: onClose)
                .accessibilityLabel(accessibilityLabel)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 2, verticalPadding: 2))
            .foregroundStyle(ThemePalette.tertiaryText)
            .help("Close search")
            .accessibilityLabel("Close search")
        }
        .font(ThemeFont.callout)
        .padding(.horizontal, 9)
        .frame(height: InterfaceScale.points(28))
        .background(ThemePalette.raisedSurface, in: RoundedRectangle(.control))
        .overlay(RoundedRectangle(.control).strokeBorder(ThemePalette.hairline))
        .padding(.horizontal, 12)
        .task { isFocused = true }
        .onChange(of: isFocused) { _, isFocused in
            if !isFocused && text.isEmpty { onClose() }
        }
    }
}
