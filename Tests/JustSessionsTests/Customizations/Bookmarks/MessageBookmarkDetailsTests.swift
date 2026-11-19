import Foundation
import Testing

@testable import JustSessions

/// A bookmark's label and tags (RDR-51), and finding bookmarks by them (SBF-05, RDR-52).
struct MessageBookmarkDetailsTests {
    private let conversationID = "Codex:session@devbox"

    private func id(_ record: Int) -> Int { TranscriptPageIdentity.entryID(record: record, part: 0) }

    @Test func bookmarksSavedBeforeLabelsLoadWithNone() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let saved = #"{"Codex:session@devbox":[{"letter":"a","entryID":\#(id(3)),"kind":"user","snippet":"Fix the build"}]}"#
        isolatedUserDefaults.userDefaults.set(Data(saved.utf8), forKey: MessageBookmarks.userDefaultsKey)

        let loaded = MessageBookmarks.load(from: isolatedUserDefaults.userDefaults).bookmarks(forConversationID: conversationID)

        #expect(loaded == [MessageBookmark(letter: "a", entryID: id(3), kind: .user, snippet: "Fix the build")])
        #expect(loaded.first?.label == nil)
        #expect(loaded.first?.tags == [])
    }

    @Test func aLabelAndTagsSurviveASaveAndLoad() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        var bookmarks = MessageBookmarks()
        guard case .added(let added) = bookmarks.toggle(entryID: id(1), kind: .assistant, snippet: "Plan", conversationID: conversationID)
        else {
            Issue.record("not added")
            return
        }

        bookmarks.setDetails(of: added, label: "Migration plan", tags: ["db", "todo"], conversationID: conversationID)
        bookmarks.save(to: isolatedUserDefaults.userDefaults)
        let loaded = MessageBookmarks.load(from: isolatedUserDefaults.userDefaults)

        #expect(loaded == bookmarks)
        #expect(loaded.bookmarks(forConversationID: conversationID).first?.label == "Migration plan")
        #expect(loaded.bookmarks(forConversationID: conversationID).first?.tags == ["db", "todo"])
    }

    @Test func aBookmarkWithoutDetailsSavesNoLabelOrTagsKeys() throws {
        let bookmark = MessageBookmark(letter: "a", entryID: id(1), kind: .user, snippet: "Hi")
        let json = String(decoding: try JSONEncoder().encode(bookmark), as: UTF8.self)

        #expect(!json.contains("label"))
        #expect(!json.contains("tags"))
    }

    @Test func aLabelIsOneTrimmedLineCutTo80Characters() {
        #expect(MessageBookmarkDetails.label(from: "  Fix\n the   build \t") == "Fix the build")
        #expect(MessageBookmarkDetails.label(from: " \n ") == nil)
        #expect(MessageBookmarkDetails.label(from: String(repeating: "x", count: 100))?.count == MessageBookmarkDetails.maximumLabelLength)
    }

    @Test func typedTagsSplitOnCommasAndSpacesWithoutHashesOrRepeats() {
        #expect(MessageBookmarkDetails.tags(fromTyped: "#db, todo  #DB，Todo bug") == ["db", "todo", "bug"])
        #expect(MessageBookmarkDetails.tags(fromTyped: " , # ,") == [])
        #expect(
            MessageBookmarkDetails.tags(fromTyped: String(repeating: "t", count: 40)).first?.count
                == MessageBookmarkDetails.maximumTagLength)
        #expect(
            MessageBookmarkDetails.tags(fromTyped: (1...20).map { "t\($0)" }.joined(separator: " ")).count
                == MessageBookmarkDetails.maximumTagCount)
        #expect(MessageBookmarkDetails.typedText(of: ["db", "todo"]) == "#db #todo")
    }

    @Test func theTagsFieldOffersTagsNotTypedYetAndThoseATagBeingTypedBegins() {
        let used = ["todo", "db", "deploy", "Today"]

        #expect(MessageBookmarkTagTyping.suggestions(from: used, typed: "") == used)
        #expect(MessageBookmarkTagTyping.suggestions(from: used, typed: "#DB ") == ["todo", "deploy", "Today"])
        #expect(MessageBookmarkTagTyping.suggestions(from: used, typed: "#db #to") == ["todo", "Today"])
        #expect(MessageBookmarkTagTyping.suggestions(from: used, typed: "#todo").isEmpty)  // "today" doesn't start with it
        #expect(
            MessageBookmarkTagTyping.suggestions(from: (1...20).map { "t\($0)" }, typed: "").count
                == MessageBookmarkTagTyping.maximumSuggestionCount)
    }

    @Test func choosingASuggestionReplacesTheTagBeingTypedOrFollowsTheOthers() {
        #expect(MessageBookmarkTagTyping.adding("todo", to: "") == "#todo ")
        #expect(MessageBookmarkTagTyping.adding("todo", to: "#db ") == "#db #todo ")
        #expect(MessageBookmarkTagTyping.adding("todo", to: "#db") == "#todo ")  // "db" is being typed
        #expect(MessageBookmarkTagTyping.adding("todo", to: "#db #to") == "#db #todo ")
        #expect(MessageBookmarkTagTyping.adding("todo", to: "#db, to") == "#db, #todo ")
        #expect(MessageBookmarkTagTyping.adding("todo", to: "#db #") == "#db #todo ")
        #expect(MessageBookmarkTagTyping.partialTag(in: "#db #to") == "to")
        #expect(MessageBookmarkTagTyping.partialTag(in: "#db ") == nil)
        #expect(MessageBookmarkTagTyping.partialTag(in: "#db #") == nil)
    }

    @Test func settingDetailsKeepsTheLetterMessageAndSnippet() {
        var bookmarks = MessageBookmarks()
        _ = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "First", conversationID: conversationID)
        let bookmark = bookmarks.bookmarks(forConversationID: conversationID)[0]

        let saved = bookmarks.setDetails(of: bookmark, label: "  Start\nhere ", tags: ["#intro", "intro"], conversationID: conversationID)

        #expect(saved == MessageBookmark(letter: "a", entryID: id(1), kind: .user, snippet: "First", label: "Start here", tags: ["intro"]))
        #expect(bookmarks.bookmarks(forConversationID: conversationID) == [saved])

        bookmarks.setDetails(of: bookmark, label: " ", tags: [], conversationID: conversationID)
        #expect(bookmarks.bookmarks(forConversationID: conversationID)[0].label == nil)
        #expect(bookmarks.bookmarks(forConversationID: conversationID)[0].tags == [])
    }

    @Test func settingDetailsOfARemovedBookmarkChangesNothing() {
        var bookmarks = MessageBookmarks()
        _ = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "First", conversationID: conversationID)
        let gone = MessageBookmark(letter: "b", entryID: id(2), kind: .user, snippet: "Second")
        let before = bookmarks

        #expect(bookmarks.setDetails(of: gone, label: "Label", tags: ["tag"], conversationID: conversationID) == nil)
        #expect(bookmarks == before)
    }

    @Test func aMovedBookmarkKeepsItsLabelAndTags() {
        var bookmarks = MessageBookmarks()
        _ = bookmarks.toggle(entryID: id(1), kind: .assistant, snippet: "Reply", conversationID: conversationID)
        let bookmark = bookmarks.setDetails(
            of: bookmarks.bookmarks(forConversationID: conversationID)[0],
            label: "Answer", tags: ["keep"], conversationID: conversationID)!

        bookmarks.update(
            bookmark, entryID: TranscriptPageIdentity.entryID(record: 1, part: 2), snippet: "Reply, longer",
            conversationID: conversationID)

        let moved = bookmarks.bookmarks(forConversationID: conversationID)[0]
        #expect(moved.label == "Answer")
        #expect(moved.tags == ["keep"])
        #expect(moved.snippet == "Reply, longer")
    }

    @Test func ensuringKeepsAnExistingBookmarkAndAddsOtherwise() {
        var bookmarks = MessageBookmarks()
        let added = bookmarks.ensure(entryID: id(1), kind: .user, snippet: "Hi", conversationID: conversationID)
        let again = bookmarks.ensure(entryID: id(1), kind: .user, snippet: "Hi", conversationID: conversationID)

        #expect(added == .added(MessageBookmark(letter: "a", entryID: id(1), kind: .user, snippet: "Hi")))
        #expect(again == .existing(MessageBookmark(letter: "a", entryID: id(1), kind: .user, snippet: "Hi")))
        #expect(bookmarks.bookmarks(forConversationID: conversationID).count == 1)

        for record in 2...26 { _ = bookmarks.ensure(entryID: id(record), kind: .user, snippet: "", conversationID: conversationID) }
        #expect(bookmarks.ensure(entryID: id(27), kind: .user, snippet: "", conversationID: conversationID) == .allLettersInUse)
        #expect(bookmarks.ensure(entryID: id(1), kind: .user, snippet: "", conversationID: conversationID).bookmark?.letter == "a")
    }

    @Test func allTagsListsTheMostUsedFirstOnceEach() {
        var bookmarks = MessageBookmarks()
        func add(_ record: Int, in conversationID: String, tags: [String]) {
            guard
                case .added(let bookmark) = bookmarks.toggle(entryID: id(record), kind: .user, snippet: "", conversationID: conversationID)
            else { return }
            bookmarks.setDetails(of: bookmark, label: nil, tags: tags, conversationID: conversationID)
        }
        add(1, in: "a", tags: ["todo", "db"])
        add(2, in: "a", tags: ["Todo"])
        add(1, in: "b", tags: ["api", "db", "todo"])

        #expect(bookmarks.allTags == ["todo", "db", "api"])
    }

    @Test func aQueryFindsLabelsAndTagsIgnoringCaseAndAccents() throws {
        let labelled = MessageBookmark(
            letter: "a", entryID: id(1), kind: .user, snippet: "Run the migration",
            label: "Café rollout", tags: ["deploy", "db"])
        let plain = MessageBookmark(letter: "b", entryID: id(2), kind: .assistant, snippet: "Deploy steps")

        let text = try #require(MessageBookmarkQuery("CAFE"))
        #expect(text.matches(labelled, includingSnippet: false))
        #expect(!text.matches(plain, includingSnippet: true))

        let tagWord = try #require(MessageBookmarkQuery("deploy"))
        #expect(tagWord.matches(labelled, includingSnippet: false))
        #expect(!tagWord.matches(plain, includingSnippet: false))
        #expect(tagWord.matches(plain, includingSnippet: true))

        let tagPrefix = try #require(MessageBookmarkQuery(" #De "))
        #expect(tagPrefix.matches(labelled, includingSnippet: false))
        #expect(!tagPrefix.matches(plain, includingSnippet: true))  // a tag search never reads the message
        #expect(try #require(MessageBookmarkQuery("#b")).matches(labelled, includingSnippet: false) == false)

        #expect(MessageBookmarkQuery("  ") == nil)
        #expect(MessageBookmarkQuery("#") == nil)
    }

    @Test func matchesListOnlySessionsWithFoundBookmarks() {
        var bookmarks = MessageBookmarks()
        guard case .added(let first) = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "", conversationID: "one"),
            case .added = bookmarks.toggle(entryID: id(1), kind: .user, snippet: "", conversationID: "two")
        else {
            Issue.record("not added")
            return
        }
        bookmarks.setDetails(of: first, label: "Release", tags: [], conversationID: "one")

        let matches = bookmarks.matches(for: MessageBookmarkQuery("release")!, includingSnippets: false)

        #expect(Array(matches.keys) == ["one"])
        #expect(matches["one"]?.map(\.letter) == ["a"])
    }
}
