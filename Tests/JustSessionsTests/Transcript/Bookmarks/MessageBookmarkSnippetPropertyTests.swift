import Foundation
import Testing

@testable import JustSessions

struct MessageBookmarkSnippetPropertyTests {
    private static let tokens = [
        "word", "Café", "☕️", "中文", "x", " ", "  ", "\n", "\n\n", "\t", "\r\n", "\r", "\u{0B}", "\u{0C}", "\u{1C}", "\u{0}",
        "\u{85}", "\u{A0}", "\u{2028}", "\u{3000}", "\u{301}", " \u{301}", "e\u{301}", "\u{200D}", "\u{FE0F}", " \u{FE0F}",
        "\u{1F3FB}", " \u{E33}", "\u{600}", "\u{600} ", "👩‍👩‍👧", "🇺🇸", String(repeating: "y", count: 70), String(repeating: " ", count: 50),
    ]

    @Test func theOnePassCollapseGivesTheSplitRulesSnippet() {
        var generator = SeededRandomNumberGenerator(seed: 0x5A1B)
        for _ in 0..<5_000 {
            let segments = (0..<Int.random(in: 1...3, using: &generator)).map { _ in
                (0..<Int.random(in: 0...120, using: &generator)).map { _ in Self.tokens.randomElement(using: &generator)! }.joined()
            }
            #expect(MessageBookmarkNavigation.collapsedHead(of: segments).snippet == Self.splitSnippet(segments), "\(segments)")
        }
        let atTheCut = String(repeating: " ", count: 317) + "abc"
        for segments in [
            [atTheCut + "\u{301} more"], [atTheCut + "d more"], [String(repeating: "x", count: 320) + "\u{301}"],
            ["a\r\nb"], [String(repeating: "\r\n", count: 200) + String(repeating: "word ", count: 30)],
            ["one", "", "  two  ", "three"], (0..<128).map { "w" + String(UnicodeScalar(UInt8($0))) + "v" },
        ] {
            #expect(MessageBookmarkNavigation.collapsedHead(of: segments).snippet == Self.splitSnippet(segments), "\(segments)")
        }
    }

    @Test func aSnippetIsCutOnlyWhenTheCutEndedItsWords() {
        let collapsed = MessageBookmarkNavigation.collapsedHead(of:)
        #expect(!collapsed([String(repeating: "word ", count: 100)]).isCut)
        #expect(!collapsed(["short", String(repeating: "z", count: 320)]).isCut)
        #expect(collapsed([String(repeating: " ", count: 300) + "a b c d e f g h i j k l m n o p q r s t u v w x y z"]).isCut)
        #expect(collapsed([String(repeating: "a ", count: 39) + String(repeating: " ", count: 241) + "longer"]).isCut)
        #expect(collapsed([String(repeating: "a ", count: 39) + String(repeating: "\u{A0}", count: 241) + "longer"]).isCut)
    }

    private static func splitSnippet(_ segments: [String]) -> String {
        var words: [Substring] = []
        var length = 0
        segments: for segment in segments {
            for word in segment.prefix(MessageBookmarkNavigation.snippetLength * 4).split(whereSeparator: \.isWhitespace) {
                words.append(word)
                length += word.count + 1
                if length >= MessageBookmarkNavigation.snippetLength { break segments }
            }
        }
        return String(words.joined(separator: " ").prefix(MessageBookmarkNavigation.snippetLength))
    }
}
