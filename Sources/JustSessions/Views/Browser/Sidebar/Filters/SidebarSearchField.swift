import SwiftUI

/// Takes keyboard focus as it opens. Escape or its × clears and closes it; so does leaving it empty.
struct SidebarSearchField: View {
    @Binding var text: String
    let placeholder: LocalizedStringKey
    let accessibilityLabel: LocalizedStringKey
    let onClose: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onExitCommand(perform: onClose)
                .accessibilityLabel(accessibilityLabel)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help("Close search")
            .accessibilityLabel("Close search")
        }
        .font(.system(size: 12))
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(ThemePalette.hairline))
        .padding(.horizontal, 12)
        .task { isFocused = true }
        .onChange(of: isFocused) { _, isFocused in
            if !isFocused && text.isEmpty { onClose() }
        }
    }
}
