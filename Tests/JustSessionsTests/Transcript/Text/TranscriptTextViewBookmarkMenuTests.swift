import AppKit
import Testing

@testable import JustSessions

/// A message's right-click menu: AppKit's own items, with Add bookmark or Remove bookmark first.
@MainActor
@Suite(.serialized)
struct TranscriptTextViewBookmarkMenuTests {
    private let conversation = TranscriptScrollViewFixture.conversation("bookmark-menu")
    private let transcript = TranscriptScrollViewFixture.pagedTranscript([
        .userMessage("Why does the build fail on the release branch?"),
        .assistantMessage("The release branch pins an older toolchain."),
        .note("The session was resumed."),
    ])

    private func id(_ record: Int) -> Int { TranscriptPageIdentity.entryID(record: record, part: 0) }

    /// Shows the transcript in a reader that keeps bookmarks, its pages not loaded, as a jump never needs here.
    private func show(
        in fixture: TranscriptScrollViewFixture, saving bookmarks: [MessageBookmark] = [],
        bookmarkState: TranscriptBookmarkState = TranscriptBookmarkState()
    ) async throws -> ConversationStore {
        MessageBookmarks(bookmarksByConversationID: bookmarks.isEmpty ? [:] : [conversation.id: bookmarks])
            .save(to: fixture.settings.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: fixture.settings.userDefaults, startsBackgroundPolling: false)
        _ = try await fixture.show(
            conversation, transcript: transcript, paging: TranscriptPagingModel(), store: store,
            bookmarkState: bookmarkState)
        return store
    }

    /// What AppKit shows for a right click in the text of the entry `entryID`.
    private func menu(forEntry entryID: Int, in fixture: TranscriptScrollViewFixture) throws -> NSMenu {
        let textView = try #require(fixture.textViews.first { $0.selectionKey?.entryIndex == entryID })
        let point = textView.convert(NSPoint(x: 4, y: 4), to: nil)
        let event = try #require(
            NSEvent.mouseEvent(
                with: .rightMouseDown, location: point, modifierFlags: [], timestamp: 0, windowNumber: fixture.window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
        return try #require(textView.menu(for: event))
    }

    @Test func aMessagesMenuStartsWithAddBookmarkAndKeepsCopy() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let store = try await show(in: fixture)

        let menu = try menu(forEntry: id(0), in: fixture)

        #expect(menu.items.first?.title == "Add bookmark")
        #expect(menu.items.dropFirst().first?.isSeparatorItem == true)
        #expect(menu.items.contains { $0.action == #selector(NSText.copy(_:)) })
        menu.performActionForItem(at: 0)
        #expect(store.messageBookmarks.bookmarks(forConversationID: conversation.id).map(\.letter) == ["a"])
        #expect(store.messageBookmarks.bookmarks(forConversationID: conversation.id).first?.entryID == id(0))
    }

    @Test func aBookmarkedMessagesMenuOffersRemoveWithItsLetter() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let bookmark = MessageBookmark(
            letter: "a", entryID: id(1), kind: .assistant, snippet: "The release branch pins an older toolchain.")
        let store = try await show(in: fixture, saving: [bookmark])

        let menu = try menu(forEntry: id(1), in: fixture)

        #expect(menu.items.first?.title == "Remove bookmark a")
        menu.performActionForItem(at: 0)
        #expect(store.messageBookmarks.bookmarks(forConversationID: conversation.id).isEmpty)
    }

    /// The fixture's borderless window takes no sheet, so this checks the reader's request, which its window shows.
    @Test func aBookmarkedMessagesMenuOffersEditWhichAsksForTheEditor() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let bookmark = MessageBookmark(
            letter: "a", entryID: id(1), kind: .assistant, snippet: "The release branch pins an older toolchain.")
        let bookmarkState = TranscriptBookmarkState()
        let store = try await show(in: fixture, saving: [bookmark], bookmarkState: bookmarkState)

        let menu = try menu(forEntry: id(1), in: fixture)

        #expect(menu.items.dropFirst().first?.title == "Edit bookmark a…")
        #expect(menu.items.dropFirst(2).first?.isSeparatorItem == true)
        menu.performActionForItem(at: 1)
        #expect(bookmarkState.editor.request?.bookmark == bookmark)
        #expect(bookmarkState.editor.request?.conversation.id == conversation.id)
        #expect(store.messageBookmarks.bookmarks(forConversationID: conversation.id) == [bookmark])  // editing adds nothing
    }

    @Test func aNotesMenuHasNoBookmarkItem() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        _ = try await show(in: fixture)

        let menu = try menu(forEntry: id(2), in: fixture)

        #expect(!menu.items.contains { $0.title == "Add bookmark" || $0.title.hasPrefix("Remove bookmark") })
        #expect(menu.items.first?.isSeparatorItem != true)
    }

    /// The stock menu enables every item with an action, so the disabled ones have none.
    @Test func withAll26LettersUsedAddBookmarkIsDisabledAndSaysWhy() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let bookmarks = MessageBookmarks.letters.enumerated().map { index, letter in
            MessageBookmark(letter: letter, entryID: id(100 + index), kind: .user, snippet: "Message \(100 + index)")
        }
        _ = try await show(in: fixture, saving: bookmarks)

        let menu = try menu(forEntry: id(0), in: fixture)
        menu.update()

        #expect(menu.items.first?.title == "Add bookmark")
        #expect(menu.items.first?.isEnabled == false)
        #expect(menu.items.first?.action == nil)
        #expect(menu.items.dropFirst().first?.title == "All 26 letters are in use. Remove a bookmark to add another.")
        #expect(menu.items.dropFirst().first?.isEnabled == false)
    }

    @Test func rightClickingTwiceDoesNotRepeatTheItems() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        _ = try await show(in: fixture)

        _ = try menu(forEntry: id(0), in: fixture)
        let menu = try menu(forEntry: id(0), in: fixture)

        #expect(menu.items.filter { $0.title == "Add bookmark" }.count == 1)
    }
}
