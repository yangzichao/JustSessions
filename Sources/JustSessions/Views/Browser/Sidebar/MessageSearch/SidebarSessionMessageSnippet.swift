import SwiftUI

struct SidebarSessionMessageSnippet: View {
    let snippet: SessionMessageSnippet
    @Environment(\.self) private var environment

    var body: some View {
        Text(attributedSnippet)
            .font(ThemeFont.detail)
            .foregroundStyle(ThemePalette.secondaryText)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedSnippet: AttributedString {
        var matchedText = AttributedString(snippet.matchedText)
        matchedText.font = ThemeFont.detail.weight(.semibold)
        matchedText.foregroundColor = Color(ThemePalette.ink.resolve(in: environment))
        return AttributedString(snippet.leadingText) + matchedText + AttributedString(snippet.trailingText)
    }
}
