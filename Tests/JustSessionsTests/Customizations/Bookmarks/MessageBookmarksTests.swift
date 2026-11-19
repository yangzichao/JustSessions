import Foundation
import Testing

@testable import JustSessions

struct MessageBookmarksTests {
    private let conversationID = "Codex:session@devbox"

    private func id(_ record: Int) -> Int { TranscriptPageIdentity.entryID(record: record, part: 0) }

    @Test func bookmarksSurviveASaveAndLoadInConversationOrder() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        var bookmarks = MessageBookmarks()
        for record in [30, 10, 20] {
            _ = bookmarks.toggle(entryID: id(record), kind: .user, snippet: "Message \(record)", conversationID: conversationID)
        }

        bookmarks.save(to: isolatedUserDefaults.userDefaults)
        let loaded = MessageBookmarks.load(from: isolatedUserDefaults.userDefaults)

        #expect(loaded == bookmarks)
        #expect(loaded.bookmarks(forConversationID: conversationID).map(\.entryID) == [id(10), id(20), id(30)])
        #expect(loaded.bookmarks(forConversationID: conversationID).map(\.letter) == ["b", "c", "a"])
        #expect(loaded.bookmarks(forConversationID: conversationID).map(\.snippet) == ["Message 10", "Message 20", "Message 30"])
    }

    @Test func eachNewBookmarkTakesTheLowestFreeLetter() {
        var bookmarks = MessageBookmarks()
        for record in 1...3 {
            _ = bookmarks.toggle(entryID: id(record), kind: .user, snippet: "", conversationID: conversationID)
        }
        let b = bookmarks.bookmarks(forConversationID: conversationID)[1]
        #expect(b.letter == "b")

        bookmarks.remove(b, conversationID: conversationID)
        let toggle = bookmarks.toggle(entryID: id(9), kind: .assistant, snippet: "", conversationID: conversationID)

        #expect(toggle == .added(MessageBookmark(letter: "b", entryID: id(9), kind: .assistant, snippet: "")))
        #expect(bookmarks.bookmarks(forConversationID: conversationID).map(\.letter) == ["a", "c", "b"])
    }

    @Test func aTwentySeventhBookmarkIsRefused() {
        var bookmarks = MessageBookmarks()
        for record in 0..<26 {
            _ = bookmarks.toggle(entryID: id(record), kind: .user, snippet: "", conversationID: conversationID)
        }
        let full = bookmarks

        let toggle = bookmarks.toggle(entryID: id(26), kind: .user, snippet: "", conversationID: conversationID)

        #expect(toggle == .allLettersInUse)
        #expect(bookmarks == full)
        #expect(Set(bookmarks.bookmarks(forConversationID: conversationID).map(\.letter)) == Set(MessageBookmarks.letters))
    }

    @Test func togglingABookmarkedMessageRemovesIt() {
        var bookmarks = MessageBookmarks()
        _ = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "First", conversationID: conversationID)
        _ = bookmarks.toggle(entryID: id(2), kind: .assistant, snippet: "Second", conversationID: conversationID)

        let toggle = bookmarks.toggle(entryID: id(2), kind: .assistant, snippet: "Second", conversationID: conversationID)

        #expect(toggle == .removed(MessageBookmark(letter: "b", entryID: id(2), kind: .assistant, snippet: "Second")))
        #expect(bookmarks.bookmarks(forConversationID: conversationID).map(\.letter) == ["a"])
    }

    @Test func eachSessionHasItsOwnLetters() {
        var bookmarks = MessageBookmarks()

        let first = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "", conversationID: "Codex:one")
        let second = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "", conversationID: "Codex:two")

        #expect(first == .added(MessageBookmark(letter: "a", entryID: id(1), kind: .user, snippet: "")))
        #expect(second == .added(MessageBookmark(letter: "a", entryID: id(1), kind: .user, snippet: "")))
    }

    @Test func removingTheLastBookmarkForgetsTheSession() {
        var bookmarks = MessageBookmarks()
        _ = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "", conversationID: conversationID)
        _ = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "", conversationID: conversationID)

        #expect(bookmarks.bookmarksByConversationID[conversationID] == nil)
        #expect(bookmarks == MessageBookmarks())

        _ = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "", conversationID: conversationID)
        bookmarks.removeAll(forConversationIDs: [conversationID])
        #expect(bookmarks.bookmarksByConversationID.isEmpty)
    }

    @Test func removingNeedsTheSameLetterAndMessage() {
        var bookmarks = MessageBookmarks()
        _ = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "", conversationID: conversationID)
        let before = bookmarks

        bookmarks.remove(MessageBookmark(letter: "a", entryID: id(2), kind: .user, snippet: ""), conversationID: conversationID)
        bookmarks.remove(MessageBookmark(letter: "b", entryID: id(1), kind: .user, snippet: ""), conversationID: conversationID)

        #expect(bookmarks == before)
    }

    @Test func aSettingOfTheWrongShapeLoadsAsNoBookmarks() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }

        isolatedUserDefaults.userDefaults.set("not data", forKey: MessageBookmarks.userDefaultsKey)
        #expect(MessageBookmarks.load(from: isolatedUserDefaults.userDefaults) == MessageBookmarks())

        isolatedUserDefaults.userDefaults.set(Data("{\"Codex:1\": 42".utf8), forKey: MessageBookmarks.userDefaultsKey)
        #expect(MessageBookmarks.load(from: isolatedUserDefaults.userDefaults) == MessageBookmarks())
    }

    @Test func loadingDropsInvalidAndDuplicateLetters() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let saved: [String: [MessageBookmark]] = [
            conversationID: [
                MessageBookmark(letter: "A", entryID: id(1), kind: .user, snippet: ""),
                MessageBookmark(letter: "ab", entryID: id(2), kind: .user, snippet: ""),
                MessageBookmark(letter: "", entryID: id(3), kind: .user, snippet: ""),
                MessageBookmark(letter: "a", entryID: id(4), kind: .user, snippet: ""),
                MessageBookmark(letter: "a", entryID: id(5), kind: .user, snippet: ""),
                MessageBookmark(letter: "b", entryID: id(4), kind: .assistant, snippet: ""),
                MessageBookmark(letter: "c", entryID: id(6), kind: .assistant, snippet: ""),
            ],
            "Codex:empty": [MessageBookmark(letter: "?", entryID: id(1), kind: .user, snippet: "")],
        ]
        isolatedUserDefaults.userDefaults.set(try JSONEncoder().encode(saved), forKey: MessageBookmarks.userDefaultsKey)

        let loaded = MessageBookmarks.load(from: isolatedUserDefaults.userDefaults)

        #expect(loaded.bookmarks(forConversationID: conversationID).map(\.letter) == ["a", "c"])
        #expect(loaded.bookmarks(forConversationID: conversationID).map(\.entryID) == [id(4), id(6)])
        #expect(loaded.bookmarksByConversationID["Codex:empty"] == nil)
    }

    @Test func updatingABookmarkKeepsItsLetter() {
        var bookmarks = MessageBookmarks()
        _ = bookmarks.toggle(entryID: id(1), kind: .assistant, snippet: "Short", conversationID: conversationID)
        _ = bookmarks.toggle(entryID: id(5), kind: .assistant, snippet: "Other", conversationID: conversationID)
        let a = bookmarks.bookmarks(forConversationID: conversationID)[0]

        let moved = TranscriptPageIdentity.entryID(record: 1, part: 1)
        bookmarks.update(a, entryID: moved, snippet: "Short and longer", conversationID: conversationID)

        #expect(
            bookmarks.bookmarks(forConversationID: conversationID)
                == [
                    MessageBookmark(letter: "a", entryID: moved, kind: .assistant, snippet: "Short and longer"),
                    MessageBookmark(letter: "b", entryID: id(5), kind: .assistant, snippet: "Other"),
                ])

        let movedA = bookmarks.bookmarks(forConversationID: conversationID)[0]
        bookmarks.update(movedA, entryID: id(5), snippet: "Other", conversationID: conversationID)

        #expect(
            bookmarks.bookmarks(forConversationID: conversationID)
                == [MessageBookmark(letter: "b", entryID: id(5), kind: .assistant, snippet: "Other")])
    }
}
