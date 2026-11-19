import AppKit
import Testing

@testable import JustSessions

@MainActor
struct TranscriptAttributedTextTests {
    private static let source = try! AttributedString(
        markdown: "😀 cafe\u{301} **bold** then `code` and bold, [a link](https://example.com)",
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )

    private static func make(ranges: [NSRange] = [], selectedRange: NSRange? = nil) -> NSAttributedString {
        TranscriptAttributedText.make(
            source: source, font: .systemFont(ofSize: 13), lineSpacing: 4,
            foreground: .black, link: .systemBlue, highlight: .systemYellow, selectedForeground: .white,
            ranges: ranges, selectedRange: selectedRange
        )
    }

    @Test func formatsEachRunOverItsOwnText() throws {
        let text = Self.make()
        let string = text.string as NSString
        let boldRange = string.range(of: "bold")
        let codeRange = string.range(of: "code")
        var boldFontRange = NSRange()
        var codeFontRange = NSRange()
        let boldFont = try #require(text.attribute(.font, at: boldRange.location, effectiveRange: &boldFontRange) as? NSFont)
        let codeFont = try #require(text.attribute(.font, at: codeRange.location, effectiveRange: &codeFontRange) as? NSFont)

        #expect(text.string == Self.source.plainText)
        #expect(boldFont.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(boldFontRange == boldRange)
        #expect(codeFont.isFixedPitch)
        #expect(codeFontRange == codeRange)
        let linkRange = string.range(of: "a link")
        var linkColorRange = NSRange()
        #expect(text.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL == URL(string: "https://example.com"))
        #expect(text.attribute(.foregroundColor, at: linkRange.location, effectiveRange: &linkColorRange) as? NSColor == .systemBlue)
        #expect(linkColorRange == linkRange)
    }

    @Test func highlightsMatchesAndTheSelectedOne() {
        let ranges = TranscriptTextSearch.ranges(of: "bold", in: Self.source.plainText)
        let text = Self.make(ranges: ranges, selectedRange: ranges.last)

        #expect(ranges.count == 2)
        #expect(ranges.allSatisfy { text.attribute(.backgroundColor, at: $0.location, effectiveRange: nil) != nil })
        #expect(text.attribute(.foregroundColor, at: ranges[1].location, effectiveRange: nil) as? NSColor == .white)
        #expect(text.attribute(.foregroundColor, at: ranges[0].location, effectiveRange: nil) as? NSColor == .black)
    }
}
