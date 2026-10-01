import Foundation
import Testing
@testable import JustSessions

struct TranscriptMarkdownParserTests {
    @Test func preservesParagraphBreaksAndSoftLineBreaks() {
        let blocks = TranscriptMarkdownParser.blocks(from: "First line\nSecond line\n\nNext paragraph")
        #expect(blocks.count == 2)
        guard case .text(let first, _) = blocks[0].content, case .text(let second, _) = blocks[1].content else {
            Issue.record("Expected two paragraphs"); return
        }
        #expect(String(first.characters) == "First line\nSecond line")
        #expect(String(second.characters) == "Next paragraph")
    }

    @Test func separatesHeadingsListsQuotesAndRules() {
        let blocks = TranscriptMarkdownParser.blocks(from: "# Title\n\n3. Ordered\n   - Nested\n\n> Quoted\n\n---")
        #expect(blocks.count == 5)
        guard case .text(let title, let headingLevel) = blocks[0].content else { Issue.record("Missing heading"); return }
        #expect(String(title.characters) == "Title")
        #expect(headingLevel == 1)
        #expect(blocks[1].listMarker == "3.")
        #expect(blocks[2].listMarker == "•")
        #expect(blocks[2].listDepth == 2)
        #expect(blocks[3].quoteDepth == 1)
        #expect(blocks[4].content == .divider)
        #expect(Set(blocks.map(\.id)).count == blocks.count)
    }

    @Test func preservesCodeForCopyingIncludingIndentationAndMarkdownSymbols() {
        let code = "let value = \"**literal**\"\n    print(value)\n"
        let blocks = TranscriptMarkdownParser.blocks(from: "Before\n\n```swift\n\(code)```\n\nAfter")
        guard case .code(let text, let language) = blocks[1].content else { Issue.record("Missing fenced code"); return }
        #expect(text == code)
        #expect(language == "swift")
        #expect(blocks.count == 3)
    }

    @Test func showsAnUnclosedCodeFenceAsCode() {
        let blocks = TranscriptMarkdownParser.blocks(from: "```python\nprint('still loading')")
        guard case .code(let text, let language) = blocks.first?.content else { Issue.record("Missing incomplete code"); return }
        #expect(text == "print('still loading')\n")
        #expect(language == "python")
    }

    @Test func keepsTableRowsAndInlineLinks() {
        let blocks = TranscriptMarkdownParser.blocks(from: "| Name | Link |\n|---|---|\n| **Reader** | [Docs](https://example.com/docs) |")
        guard case .table(let table) = blocks.first?.content else { Issue.record("Missing table"); return }
        #expect(table.rows.count == 2)
        #expect(table.rows[0].isHeader)
        #expect(!table.rows[1].isHeader)
        #expect(table.rows[1].cells.map { String($0.characters) } == ["Reader", "Docs"])
        #expect(table.rows[1].cells[0].runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(table.rows[1].cells[1].runs.first?.link == URL(string: "https://example.com/docs"))
    }

    @Test func onlyFirstParagraphOfAListItemHasAMarker() {
        let blocks = TranscriptMarkdownParser.blocks(from: "- First paragraph\n\n  More detail\n\n- Next item")
        #expect(blocks.count == 3)
        #expect(blocks.map(\.listMarker) == ["•", nil, "•"])
    }
}
