import Foundation
import Testing
@testable import JustSessions

struct SearchableSessionTextTests {
    private func text(_ entries: [(Int, [String])]) -> SearchableSessionText {
        SearchableSessionText(SessionMessageText(entries: entries.map { SessionMessageText.Entry(id: $0.0, segments: $0.1) }))
    }

    private func query(_ text: String) throws -> SessionMessageQuery {
        try #require(SessionMessageQuery(text))
    }

    @Test func findsTheFirstEntryWithTheTextInReadingOrder() throws {
        let session = text([(10, ["Nothing yet"]), (20, ["The cache key is stale"]), (30, ["Another cache key"])])

        let match = try #require(session.firstMatch(of: try query("cache key")))

        #expect(match.entryID == 20)
        #expect(match.snippet == SessionMessageSnippet(leadingText: "The ", matchedText: "cache key", trailingText: " is stale"))
    }

    @Test func matchesAsFindDoesIgnoringCaseAndAccents() throws {
        let session = text([(1, ["Fixed. Café ☕️ 修好了"])])

        #expect(session.firstMatch(of: try query("CAFE"))?.snippet.matchedText == "Café")
        #expect(session.firstMatch(of: try query("fixed. café"))?.snippet.matchedText == "Fixed. Café")
        #expect(session.firstMatch(of: try query("修好"))?.snippet.matchedText == "修好")
        #expect(session.firstMatch(of: try query("修坏")) == nil)
    }

    @Test func aMatchStaysWithinOneSegment() throws {
        let session = text([(1, ["swift", "build"]), (2, ["swift build"])])

        #expect(session.firstMatch(of: try query("swiftbuild")) == nil)
        #expect(session.firstMatch(of: try query("ftbu")) == nil)
        #expect(session.firstMatch(of: try query("swift build"))?.entryID == 2)
    }

    @Test func findsTextInAnyListedSegment() throws {
        let session = text([(1, ["First paragraph", "Bash · swift test", "| cell |"]), (2, ["Done"])])

        #expect(session.firstMatch(of: try query("swift test"))?.entryID == 1)
        #expect(session.firstMatch(of: try query("done"))?.entryID == 2)
    }

    @Test func anEmptySessionHasNoMatch() throws {
        #expect(text([]).firstMatch(of: try query("anything")) == nil)
        #expect(text([(1, [""])]).firstMatch(of: try query("anything")) == nil)
    }

    @Test func aQueryOfOnlyWhitespaceSearchesNothing() {
        #expect(SessionMessageQuery("  \n ") == nil)
        #expect(SessionMessageQuery("  cache  ")?.text == "cache")
    }
}
