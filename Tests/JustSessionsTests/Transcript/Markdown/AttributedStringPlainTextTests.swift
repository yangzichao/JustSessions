import Foundation
import Testing
@testable import JustSessions

struct AttributedStringPlainTextTests {
    /// The same text as `String(text.characters)`, for a whole string and part of one, across several runs, emoji, and
    /// combining marks.
    @Test func givesTheSameTextAsItsCharacters() throws {
        let text = try AttributedString(
            markdown: "😀 **bold 👩‍👩‍👧** cafe\u{301} *e\u{301}tude* 東京 `code`",
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        let middle = text.index(text.startIndex, offsetByCharacters: 2)..<text.index(text.endIndex, offsetByCharacters: -3)

        #expect(text.plainText == String(text.characters))
        #expect(text.plainText.contains("bold 👩‍👩‍👧"))
        #expect(text[middle].plainText == String(text[middle].characters))
        #expect(AttributedString().plainText.isEmpty)
    }
}
