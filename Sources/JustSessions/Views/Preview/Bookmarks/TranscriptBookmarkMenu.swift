import SwiftUI

/// SwiftUI builds a menu's items with its view, not when it opens, so every title here depends only on the bookmarks;
/// Add or remove bookmark decides its message when chosen.
struct TranscriptBookmarkMenu: View {
    let bookmarks: [MessageBookmark]
    let assistantName: String
    let onGoTo: (MessageBookmark) -> Void
    let onGoToAdjacent: (_ forward: Bool) -> Void
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onRemoveAll: () -> Void
    @Environment(\.locale) private var locale
    @State private var isConfirmingRemoveAll = false

    var body: some View {
        // No menu item has a shortcut: its key equivalent would take ⌘D ahead of the menu bar's.
        Menu {
            if bookmarks.isEmpty { Text("No bookmarks in this conversation") }
            ForEach(bookmarks, id: \.letter) { bookmark in
                Button {
                    onGoTo(bookmark)
                } label: {
                    if bookmark.label != nil {
                        Text(verbatim: menuTitle(of: bookmark))
                    } else {
                        Text("\(bookmark.letter) · \(speaker(of: bookmark)): \(bookmark.menuSnippet)")
                    }
                }
            }
            Divider()
            Button("Next bookmark") { onGoToAdjacent(true) }.disabled(bookmarks.isEmpty)
            Button("Previous bookmark") { onGoToAdjacent(false) }.disabled(bookmarks.isEmpty)
            Divider()
            Button("Add or remove bookmark", action: onToggle)
            Button("Edit bookmark…", action: onEdit)
            if bookmarks.count >= MessageBookmarks.letters.count {
                Text("All 26 letters are in use. Remove a bookmark to add another.")
            }
            Divider()
            Button("Remove all bookmarks…", role: .destructive) { isConfirmingRemoveAll = true }.disabled(bookmarks.isEmpty)
        } label: {
            Image(systemName: bookmarks.isEmpty ? "bookmark" : "bookmark.fill")
                .frame(width: InterfaceScale.points(24), height: InterfaceScale.points(24))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Bookmarks (⌘D, ⌘', ⇧⌘')")
        .accessibilityLabel("Bookmarks")
        .accessibilityValue(Text(bookmarks.count == 1 ? "1 bookmark" : "\(bookmarks.count) bookmarks"))
        .accessibilityIdentifier("preview.bookmarks")
        .alert("Remove all bookmarks in this conversation?", isPresented: $isConfirmingRemoveAll) {
            Button("Remove all", role: .destructive, action: onRemoveAll).keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The conversation itself isn't changed.")
        }
        .dismissesOnClickOutside(isPresented: $isConfirmingRemoveAll)
    }

    private func menuTitle(of bookmark: MessageBookmark) -> String {
        let tags = bookmark.tags.isEmpty ? "" : "  " + MessageBookmarkDetails.typedText(of: bookmark.tags)
        return "\(bookmark.letter) · \(bookmark.menuTitle)\(tags)"
    }

    private func speaker(of bookmark: MessageBookmark) -> String {
        bookmark.kind == .user
            ? AppLocalization.string("You", language: AppInterfaceLanguage(identifier: locale.identifier)) : assistantName
    }
}
