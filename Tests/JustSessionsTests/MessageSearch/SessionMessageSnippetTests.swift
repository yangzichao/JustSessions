import Foundation
import Testing
@testable import JustSessions

struct SessionMessageSnippetTests {
    private func snippet(_ segment: String, around matched: String) throws -> SessionMessageSnippet {
        SessionMessageSnippet(segment: segment, match: try #require(segment.range(of: matched)))
    }

    @Test func aShortMessageShowsWhole() throws {
        #expect(try snippet("Fix the build", around: "the") == SessionMessageSnippet(leadingText: "Fix ", matchedText: "the", trailingText: " build"))
    }

    @Test func aLongMessageIsCutAroundTheMatchWithEllipses() throws {
        let before = String(repeating: "b", count: 100)
        let after = String(repeating: "a", count: 300)

        let cut = try snippet(before + "MATCH" + after, around: "MATCH")

        #expect(cut.leadingText == "…" + String(repeating: "b", count: SessionMessageSnippet.leadingCharacterCount))
        #expect(cut.matchedText == "MATCH")
        #expect(cut.trailingText == String(repeating: "a", count: SessionMessageSnippet.trailingCharacterCount) + "…")
    }

    @Test func whitespaceRunsAndLineBreaksReadAsSingleSpacesWithNoneAtEitherEnd() throws {
        let cut = try snippet("  One\n\n  two\tthe key  \n", around: "two")

        #expect(cut.text == "One two the key")
    }

    @Test func textAfterTheMatchEndsBeforeAnyWhitespaceWhereItIsCut() throws {
        let cut = try snippet("key" + String(repeating: "a", count: SessionMessageSnippet.trailingCharacterCount - 1) + "  \n tail", around: "key")

        #expect(cut.trailingText == String(repeating: "a", count: SessionMessageSnippet.trailingCharacterCount - 1) + "…")
    }

    @Test func textBeforeTheMatchStartsAfterAnyWhitespaceWhereItIsCut() throws {
        let cut = try snippet(String(repeating: "x", count: 30) + "\n\n\n" + String(repeating: "y", count: 22) + "key", around: "key")

        #expect(cut.leadingText == "…" + String(repeating: "y", count: 22))
    }
}
