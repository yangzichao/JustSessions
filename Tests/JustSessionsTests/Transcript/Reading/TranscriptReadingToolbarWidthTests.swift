import AppKit
import SwiftUI
import Testing

@testable import JustSessions

/// The reading toolbar keeps its buttons on one line in a reading window at its minimum width. This runs at the default
/// interface size, since a test process has defaults of its own; the 150% size is a manual check.
@MainActor
struct TranscriptReadingToolbarWidthTests {
    @Test func theToolbarWithItsBookmarkMenuFitsAReadingWindowAtItsMinimumWidth() {
        let bookmarks = MessageBookmarks.letters.prefix(3).enumerated().map { index, letter in
            MessageBookmark(
                letter: letter, entryID: TranscriptPageIdentity.entryID(record: index, part: 0), kind: .user,
                snippet: "Why does the build fail on the release branch")
        }
        let toolbar = TranscriptReadingToolbar(
            fontSize: .constant(TranscriptReadingTextSize.defaultSize), readingWidth: .constant(.readable), messageCount: 12_345,
            onFirstMessage: {}, onLatestMessage: {}, onFind: {},
            bookmarkMenu: TranscriptBookmarkMenu(
                bookmarks: bookmarks, assistantName: ConversationProvider.codex.rawValue,
                onGoTo: { _ in }, onGoToAdjacent: { _ in }, onToggle: {}, onEdit: {}, onRemoveAll: {})
        )
        let hostingController = NSHostingController(rootView: toolbar)

        // A reading window has no button that opens another, so this is its whole toolbar.
        let size = hostingController.sizeThatFits(in: CGSize(width: 400, height: 1_000))
        #expect(size.width <= 400)
        // Without room, a title wraps onto a second line rather than the toolbar growing wider.
        #expect(size.height == hostingController.sizeThatFits(in: CGSize(width: 1_000, height: 1_000)).height)
    }
}
