import Foundation
import Testing

@testable import JustSessions

struct ConversationOutlineSnippetTests {
    private static let tokens = [
        "word", "Café", "☕️", "中文", "e\u{301}", "\u{301}", " \u{301}", "\u{600}", "\u{600} ", "\u{FEFF}", "\u{A0}", "\u{2028}",
        "\u{3000}", "\u{85}", "\u{200B}", " ", "  ", "   ", "    ", "\n", "\n\n", "\n ", "\n   ", " \n", "  \n", "x1", "2.", "a-b", "-",
        "c+d", "+", "e=f", "=", "(x)", ":", "\n:-", "\n:-:", "/", "@", "%", "$", "^", "{", "}", "?", ";", "'", "\"quoted\"", "--", "...",
        "http://example.com", "www.example.com", "a@b.com", String(repeating: " ", count: 40), String(repeating: "\n", count: 12),
        String(repeating: "y", count: 70), "lorem ipsum dolor sit amet ",
    ]

    @Test func anInertHeadGivesTheParsedHeadsSnippet() {
        var generator = SeededRandomNumberGenerator(seed: 0x1E47)
        var skippedParseCount = 0
        for _ in 0..<3_000 {
            var text = ""
            let length = Int.random(in: 1...520, using: &generator)
            while text.count < length { text += Self.tokens.randomElement(using: &generator)! }
            let head = String(text.prefix(ConversationOutlineBuilder.snippetSourceLength))
            let entry = TranscriptEntry(id: 0, content: .assistantMessage(text), timestamp: nil, startsTurn: false)
            let parsed = MessageBookmarkNavigation.snippet(
                of: TranscriptEntry(id: 0, content: .assistantMessage(head), timestamp: nil, startsTurn: false))
            #expect(ConversationOutlineBuilder.snippet(of: entry) == parsed, "\(head.debugDescription)")
            if ConversationOutlineBuilder.isMarkdownInert(head), !MessageBookmarkNavigation.collapsedHead(of: [head]).isCut {
                skippedParseCount += 1
            }
        }
        #expect(skippedParseCount > 200, "\(skippedParseCount)")
        let spaced = "Start" + String(repeating: "\n", count: 330) + "end of the reply"
        #expect(ConversationOutlineBuilder.isMarkdownInert(spaced))
        #expect(
            ConversationOutlineBuilder.snippet(
                of: TranscriptEntry(id: 0, content: .assistantMessage(spaced), timestamp: nil, startsTurn: false))
                == "Start end of the reply")
    }

    @Test func markdownIsNeverInert() {
        let inert = ConversationOutlineBuilder.isMarkdownInert
        #expect(inert("Fixed. Café ☕️ the build passes, 3 of 4 tests ran (x = 1 + 2) at 10:30 - see www.example.com.\n\nNext line"))
        #expect(inert("Trailing spaces  \n   three leading spaces"))
        for markdown in [
            "**bold**", "`code`", "_under_", "[link](x)", "<b>", "&amp;", "a\\b", "~~gone~~", "| a | b |", "![image](x)",
            "# Heading", "> quote", "- item", "+ item", "1. first", "Title\n===", "Title\n---", "Fixed it\n:-:\nsee above",
            "Done\n   :--", "    code", "\tcode",
            "a\r\nb", "a\u{0}b", " \u{301}x", "\u{600} \nb", "\u{FEFF}text",
        ] {
            #expect(!inert(markdown), "\(markdown.debugDescription)")
        }
    }
}
