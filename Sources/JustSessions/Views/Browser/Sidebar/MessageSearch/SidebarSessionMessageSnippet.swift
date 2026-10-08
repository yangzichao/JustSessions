import SwiftUI

/// Under a session's title while searching: the text around the session's first match in its messages, the match
/// in bold.
struct SidebarSessionMessageSnippet: View {
    let snippet: SessionMessageSnippet
    @Environment(\.self) private var environment

    var body: some View {
        Text(attributedSnippet)
            .font(.system(size: 11))
            .foregroundStyle(ThemePalette.secondaryText)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedSnippet: AttributedString {
        var matchedText = AttributedString(snippet.matchedText)
        matchedText.font = .system(size: 11, weight: .semibold)
        matchedText.foregroundColor = Color(ThemePalette.ink.resolve(in: environment))
        return AttributedString(snippet.leadingText) + matchedText + AttributedString(snippet.trailingText)
    }
}
