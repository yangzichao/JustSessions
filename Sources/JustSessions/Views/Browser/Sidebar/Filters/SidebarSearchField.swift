import SwiftUI

struct SidebarSearchField: View {
    @Binding var text: String
    let placeholder: String
    let accessibilityLabel: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Clear \(placeholder.lowercased())")
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(ThemePalette.hairline))
        .padding(.horizontal, 12)
    }
}
