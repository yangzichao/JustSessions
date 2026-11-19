import Foundation
import Testing

@testable import JustSessions

struct TranscriptPageSourceOptionsTests {
    @Test func skippingMarkdownKeepsEntriesAndIDs() async throws {
        let fixture = try TranscriptPagingFixture(count: 120)
        defer { fixture.remove() }
        let source = TranscriptPageSource(file: fixture.file, provider: .codex)
        let prepared = try await source.read(.first)
        let plain = try await source.read(.first, preparesMarkdown: false)
        #expect(plain.entries.map(\.id) == prepared.entries.map(\.id))
        #expect(plain.entries.map(\.content) == prepared.entries.map(\.content))
        #expect(prepared.entries.allSatisfy { $0.markdown != nil })
        #expect(plain.entries.allSatisfy { $0.markdown == nil })
    }

    @Test func perCallLimitsKeepTheReadersEntryIDs() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        try SampleTranscriptLines.fileContents(Array(repeating: SampleTranscriptLines.claude, count: 300).flatMap { $0 }).write(
            to: fixture.file)
        let source = TranscriptPageSource(file: fixture.file, provider: .claude)
        let readers = try await Self.pages(of: source, limits: nil)
        let outlines = try await Self.pages(of: source, limits: ConversationOutlineReader.pageLimits(for: .claude))
        #expect(outlines.count < readers.count)
        #expect(Self.messageIDs(in: outlines) == Self.messageIDs(in: readers))
        #expect(Self.messageIDs(in: readers).count == 300 * 4)
    }

    private static func pages(of source: TranscriptPageSource, limits: TranscriptPageLimits?) async throws -> [TranscriptPage] {
        var pages = [try await source.read(.first, refreshIndex: true, limits: limits, preparesMarkdown: limits == nil)]
        while pages.last!.hasLater {
            pages.append(try await source.read(.after(pages.last!.records.upperBound), limits: limits, preparesMarkdown: limits == nil))
        }
        return pages
    }

    private static func messageIDs(in pages: [TranscriptPage]) -> [Int] {
        pages.flatMap(\.entries).filter { MessageBookmark.Kind($0.content) != nil }.map(\.id)
    }
}
