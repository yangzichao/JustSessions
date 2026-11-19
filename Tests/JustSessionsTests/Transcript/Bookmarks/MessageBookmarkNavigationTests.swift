import Foundation
import Testing

@testable import JustSessions

struct MessageBookmarkNavigationTests {
    private func id(_ record: Int, part: Int = 0) -> Int { TranscriptPageIdentity.entryID(record: record, part: part) }

    private func entry(_ record: Int, part: Int = 0, _ content: TranscriptEntry.Content) -> TranscriptEntry {
        TranscriptEntry(id: id(record, part: part), content: content, timestamp: nil, startsTurn: true)
    }

    private func bookmark(
        _ letter: String, at record: Int, part: Int = 0, kind: MessageBookmark.Kind = .user,
        snippet: String = ""
    ) -> MessageBookmark {
        MessageBookmark(letter: letter, entryID: id(record, part: part), kind: kind, snippet: snippet)
    }

    private var image: TranscriptImage { .undecoded }

    @Test func onlyYourMessagesAndRepliesHaveAKind() {
        #expect(MessageBookmark.Kind(.userMessage("Hi")) == .user)
        #expect(MessageBookmark.Kind(.assistantMessage("Hello")) == .assistant)
        #expect(MessageBookmark.Kind(.toolCalls(["Read file"])) == nil)
        #expect(MessageBookmark.Kind(.note("Compacted")) == nil)
        #expect(MessageBookmark.Kind(.userImage(image)) == nil)
        #expect(MessageBookmark.Kind(.toolResultImage(image)) == nil)
        #expect(MessageBookmarkNavigation.snippet(of: entry(1, .toolCalls(["Read file"]))) == nil)
    }

    @Test func aSnippetIsTheHeadOfTheTextFindSeesOnOneLine() throws {
        let long = String(repeating: "word ", count: 40)
        let reply = entry(1, .assistantMessage("## Title\n\n**bold**   text\n\n- item\n\n\(long)"))

        let snippet = try #require(MessageBookmarkNavigation.snippet(of: reply))

        #expect(snippet.hasPrefix("Title bold text item word word"))
        #expect(snippet.count <= MessageBookmarkNavigation.snippetLength)
        #expect(!snippet.contains("\n") && !snippet.contains("  ") && !snippet.contains("*") && !snippet.contains("#"))
        #expect(MessageBookmarkNavigation.snippet(of: entry(2, .userMessage("  Why\tdoes\n\nit fail?  "))) == "Why does it fail?")
    }

    @Test func nextGoesToTheFirstBookmarkAfterTheOriginAndWraps() {
        let bookmarks = [bookmark("a", at: 10), bookmark("b", at: 20), bookmark("c", at: 30)]

        #expect(MessageBookmarkNavigation.bookmark(after: id(5), in: bookmarks)?.letter == "a")
        #expect(MessageBookmarkNavigation.bookmark(after: id(10), in: bookmarks)?.letter == "b")
        #expect(MessageBookmarkNavigation.bookmark(after: id(25), in: bookmarks)?.letter == "c")
        #expect(MessageBookmarkNavigation.bookmark(after: id(30), in: bookmarks)?.letter == "a")
    }

    @Test func previousGoesToTheLastBookmarkBeforeTheOriginAndWraps() {
        let bookmarks = [bookmark("a", at: 10), bookmark("b", at: 20), bookmark("c", at: 30)]

        #expect(MessageBookmarkNavigation.bookmark(before: id(35), in: bookmarks)?.letter == "c")
        #expect(MessageBookmarkNavigation.bookmark(before: id(30), in: bookmarks)?.letter == "b")
        #expect(MessageBookmarkNavigation.bookmark(before: id(15), in: bookmarks)?.letter == "a")
        #expect(MessageBookmarkNavigation.bookmark(before: id(10), in: bookmarks)?.letter == "c")
    }

    @Test func withoutAnOriginNextIsTheFirstAndPreviousTheLast() {
        let bookmarks = [bookmark("b", at: 10), bookmark("a", at: 20)]

        #expect(MessageBookmarkNavigation.bookmark(after: nil, in: bookmarks)?.letter == "b")
        #expect(MessageBookmarkNavigation.bookmark(before: nil, in: bookmarks)?.letter == "a")
        #expect(MessageBookmarkNavigation.bookmark(after: nil, in: []) == nil)
        #expect(MessageBookmarkNavigation.bookmark(before: id(1), in: []) == nil)
    }

    @Test func aSingleBookmarkIsItsOwnNextAndPrevious() {
        let bookmarks = [bookmark("a", at: 10)]

        #expect(MessageBookmarkNavigation.bookmark(after: id(10), in: bookmarks)?.letter == "a")
        #expect(MessageBookmarkNavigation.bookmark(before: id(10), in: bookmarks)?.letter == "a")
    }

    @Test func locateFindsTheExactMessage() {
        let entries = [entry(1, .userMessage("First question")), entry(2, .assistantMessage("An answer")), entry(3, .userMessage("Next"))]
        let saved = bookmark("a", at: 2, kind: .assistant, snippet: "An answer")

        #expect(MessageBookmarkNavigation.locate(saved, in: entries, hasEarlier: true, hasLater: true) == .found(entries[1]))
    }

    @Test func locateFollowsAMessageWhosePartMovedWithinItsRecord() {
        let entries = [
            entry(1, .userMessage("Question")), entry(2, part: 0, .assistantMessage("Thinking first")),
            entry(2, part: 1, .assistantMessage("The real answer")), entry(3, .userMessage("Thanks")),
        ]
        let saved = bookmark("a", at: 2, part: 0, kind: .assistant, snippet: "The real answer")

        #expect(MessageBookmarkNavigation.locate(saved, in: entries, hasEarlier: true, hasLater: true) == .found(entries[2]))
    }

    /// After an OpenCode `/undo`, another message can take the record and part a bookmark saved.
    @Test func locateReportsAnotherMessageAtTheSameIDAsMissing() {
        let entries = [
            entry(1, .userMessage("Question")), entry(2, .userMessage("A different message")), entry(3, .assistantMessage("Reply")),
        ]
        let saved = bookmark("a", at: 2, snippet: "The message that was undone")

        #expect(MessageBookmarkNavigation.locate(saved, in: entries, hasEarlier: true, hasLater: true) == .missing(landingEntryID: id(2)))
    }

    @Test func locateReportsAGoneMessageInsideTheLoadedRecordsAsMissingAtTheNextEntry() {
        let entries = [entry(10, .userMessage("Before")), entry(14, .assistantMessage("After")), entry(20, .userMessage("Later"))]
        let saved = bookmark("a", at: 12, snippet: "On the abandoned branch")

        #expect(MessageBookmarkNavigation.locate(saved, in: entries, hasEarlier: true, hasLater: true) == .missing(landingEntryID: id(14)))
    }

    @Test func locateAsksForALoadOutsideTheLoadedRecords() {
        let entries = [entry(100, .userMessage("Loaded")), entry(101, .assistantMessage("Also loaded"))]

        #expect(MessageBookmarkNavigation.locate(bookmark("a", at: 50), in: entries, hasEarlier: true, hasLater: true) == .notLoaded)
        #expect(MessageBookmarkNavigation.locate(bookmark("a", at: 150), in: entries, hasEarlier: true, hasLater: true) == .notLoaded)
        #expect(MessageBookmarkNavigation.locate(bookmark("a", at: 50), in: [], hasEarlier: false, hasLater: false) == .notLoaded)
    }

    @Test func locateReportsABookmarkPastTheSessionsEndAsMissing() {
        let entries = [entry(100, .userMessage("Loaded")), entry(101, .assistantMessage("The last reply"))]

        #expect(
            MessageBookmarkNavigation.locate(
                bookmark("a", at: 150, snippet: "Truncated away"), in: entries, hasEarlier: true, hasLater: false)
                == .missing(landingEntryID: id(101)))
        #expect(
            MessageBookmarkNavigation.locate(
                bookmark("a", at: 50, snippet: "Before the start"), in: entries, hasEarlier: false, hasLater: true)
                == .missing(landingEntryID: id(100)))
    }

    @Test func aReplyThatKeptStreamingStillMatches() {
        let saved = bookmark("a", at: 2, kind: .assistant, snippet: "The build fails because")
        let grown = entry(2, .assistantMessage("THE BUILD FAILS BECAUSE the release branch pins an old toolchain."))

        #expect(MessageBookmarkNavigation.matches(saved, grown))
        #expect(!MessageBookmarkNavigation.matches(saved, entry(2, .userMessage("The build fails because"))))
        #expect(!MessageBookmarkNavigation.matches(saved, entry(2, .assistantMessage("The tests fail because"))))
    }

    @Test func theMessageBeingReadPrefersTheSeekTarget() {
        let entries = [entry(1, .userMessage("One")), entry(2, .assistantMessage("Two")), entry(3, .userMessage("Three"))]

        let read = MessageBookmarkNavigation.messageBeingRead(in: entries, visibleEntryIDs: [id(1), id(2)], seekTarget: id(3))

        #expect(read == entries[2])
    }

    @Test func aSeekTargetThatIsNoMessageIsSkipped() {
        let entries = [entry(1, .toolCalls(["Read file"])), entry(2, .assistantMessage("Two")), entry(3, .userMessage("Three"))]

        #expect(MessageBookmarkNavigation.messageBeingRead(in: entries, visibleEntryIDs: [id(2), id(3)], seekTarget: id(1)) == entries[1])
        #expect(MessageBookmarkNavigation.messageBeingRead(in: entries, visibleEntryIDs: [id(2), id(3)], seekTarget: id(9)) == entries[1])
    }

    @Test func theMessageBeingReadSkipsToolCallsToTheFirstVisibleMessage() {
        let entries = [
            entry(1, .userMessage("Earlier")), entry(2, .toolCalls(["Read file"])), entry(3, .toolResultImage(image)),
            entry(4, .assistantMessage("Shown")), entry(5, .userMessage("Below")),
        ]

        let read = MessageBookmarkNavigation.messageBeingRead(in: entries, visibleEntryIDs: [id(2), id(3), id(4), id(5)], seekTarget: nil)

        #expect(read == entries[3])
    }

    @Test func theMessageBeingReadFallsBackToTheMessageAboveAToolRun() {
        let entries = [
            entry(1, .userMessage("Earlier")), entry(2, .assistantMessage("Above")), entry(3, .toolCalls(["Read file"])),
            entry(4, .note("Compacted")), entry(5, .userMessage("Below")),
        ]

        #expect(MessageBookmarkNavigation.messageBeingRead(in: entries, visibleEntryIDs: [id(3), id(4)], seekTarget: nil) == entries[1])
        #expect(MessageBookmarkNavigation.messageBeingRead(in: entries, visibleEntryIDs: [], seekTarget: nil) == nil)
    }

    @Test func thePointersMessageIsTheEntryOrTheNearestMessageAboveIt() {
        let entries = [
            TranscriptEntry(id: 1, content: .note("Compacted"), timestamp: nil, startsTurn: false),
            TranscriptEntry(id: 2, content: .userMessage("Fix it"), timestamp: nil, startsTurn: true),
            TranscriptEntry(id: 3, content: .toolCalls(["Run make"]), timestamp: nil, startsTurn: true),
            TranscriptEntry(id: 4, content: .assistantMessage("Done"), timestamp: nil, startsTurn: false),
        ]

        #expect(MessageBookmarkNavigation.message(at: 4, in: entries)?.id == 4)
        #expect(MessageBookmarkNavigation.message(at: 3, in: entries)?.id == 2)
        #expect(MessageBookmarkNavigation.message(at: 1, in: entries)?.id == 2)
        #expect(MessageBookmarkNavigation.message(at: 9, in: entries) == nil)
    }
}
