import AppKit
import SwiftUI
import Testing

@testable import JustSessions

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

        let size = hostingController.sizeThatFits(in: CGSize(width: 400, height: 1_000))
        #expect(size.width <= 400)
        #expect(size.height == hostingController.sizeThatFits(in: CGSize(width: 1_000, height: 1_000)).height)
    }
}
