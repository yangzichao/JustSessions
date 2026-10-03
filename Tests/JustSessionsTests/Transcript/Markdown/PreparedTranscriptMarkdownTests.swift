import Foundation
import Testing
@testable import JustSessions

struct PreparedTranscriptMarkdownTests {
    @Test func pagesPrepareMarkdownAndAssemblyKeepsItForSearch() async throws {
        let fixture = try TranscriptPagingFixture(count: 3)
        defer { fixture.remove() }
        let page = try await TranscriptPageSource(file: fixture.file, provider: .codex).read(.latest)
        #expect(page.entries.allSatisfy { $0.markdown != nil })
        let content = TranscriptPageAssembler.transcript(pages: [page])
        #expect(content.entries.map(\.markdown) == page.entries.map(\.markdown))
        #expect(try TranscriptSearchIndex(transcript: content).matches(for: "Message").count == 3)
        // The export reader retains original strings without allocating rendered blocks for the whole log.
        #expect(try CodexTranscriptReader().read(fixture.file).entries.allSatisfy { $0.markdown == nil })
    }

    @Test func cachedSegmentsPreserveCodeTablesAndLineBreaks() {
        let text = "First\nSecond\n\n```swift\nlet code = 1\n```\n\n| A | B |\n| --- | --- |\n| C | D |"
        let prepared = PreparedTranscriptMarkdown(text: text)
        let entry = TranscriptEntry(id: 0, content: .assistantMessage(text), timestamp: nil, startsTurn: true, markdown: prepared)
        #expect(TranscriptSearchSegments.texts(in: entry) == TranscriptSearchSegments.texts(in: entry.content))
        #expect(prepared.searchSegments.contains("First\nSecond"))
        #expect(prepared.searchSegments.contains("let code = 1\n"))
        #expect(prepared.searchSegments.suffix(4) == ["A", "B", "C", "D"])
    }
}
