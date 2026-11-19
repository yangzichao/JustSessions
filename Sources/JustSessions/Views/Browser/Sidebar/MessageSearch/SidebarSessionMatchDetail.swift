import SwiftUI

struct SidebarSessionMatchDetail: View {
    let bookmarks: [MessageBookmark]
    let messageMatch: SessionMessageMatch?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !bookmarks.isEmpty { SidebarSessionBookmarkMatch(bookmarks: bookmarks) }
            if let messageMatch { SidebarSessionMessageSnippet(snippet: messageMatch.snippet) }
        }
    }
}

struct SidebarSessionBookmarkMatch: View {
    let bookmarks: [MessageBookmark]

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bookmark.fill")
                .font(ThemeFont.glyph(.control))
                .accessibilityHidden(true)
            Text(verbatim: Self.text(of: [bookmarks[0]]) ?? "")
                .lineLimit(1)
                .truncationMode(.tail)
            if bookmarks.count > 1 {
                Text("+\(bookmarks.count - 1)")
                    .layoutPriority(1)
            }
        }
        .font(ThemeFont.detail)
        .foregroundStyle(ThemePalette.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func text(of bookmarks: [MessageBookmark]) -> String? {
        guard !bookmarks.isEmpty else { return nil }
        return bookmarks.map { bookmark in
            let tags = bookmark.tags.isEmpty ? "" : " " + MessageBookmarkDetails.typedText(of: bookmark.tags)
            return "\(bookmark.letter) · \(bookmark.label ?? bookmark.menuSnippet)\(tags)"
        }.joined(separator: ", ")
    }
}
