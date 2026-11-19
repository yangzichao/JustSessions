import Foundation
import Testing

@testable import JustSessions

/// The conversation map's blocks (TAB-10): the reader's message IDs, tool runs merged whatever the page size, and line
/// widths as the map draws them.
struct ConversationOutlineBuilderTests {
    typealias Block = ConversationOutline.Block

    @Test(arguments: [
        (ConversationProvider.claude, Array(repeating: SampleTranscriptLines.claude, count: 40).flatMap { $0 }),
        (ConversationProvider.codex, Array(repeating: SampleTranscriptLines.codex, count: 40).flatMap { $0 }),
        (ConversationProvider.pi, SampleTranscriptLines.pi),
    ])
    func messageBlocksKeepTheReadersEntryIDs(provider: ConversationProvider, lines: [String]) async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        try SampleTranscriptLines.fileContents(lines).write(to: fixture.file)
        let conversation = Conversation.fixture(provider: provider, sourceFile: fixture.file)
        let outline = try #require(try await ConversationOutlineReader(conversation).update())

        let source = TranscriptPageSource(file: fixture.file, provider: provider)
        var pages = [try await source.read(.first)]
        while pages.last!.hasLater { pages.append(try await source.read(.after(pages.last!.records.upperBound))) }
        let readerMessages = pages.flatMap(\.entries).compactMap { entry in
            MessageBookmark.Kind(entry.content).map { (entry.id, $0 == .user ? Block.Kind.user : .assistant) }
        }
        let blockMessages = outline.blocks.filter(\.isMessage).map { ($0.entryID, $0.kind) }

        #expect(!readerMessages.isEmpty)
        #expect(blockMessages.map(\.0) == readerMessages.map(\.0))
        #expect(blockMessages.map(\.1) == readerMessages.map(\.1))
        #expect(outline.messageCount == readerMessages.count)
    }

    @Test func toolRunsMergeTheSameWhateverThePageSize() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let codex = SampleTranscriptLines.codex
        try SampleTranscriptLines.fileContents([codex[1]] + Array(repeating: codex[2], count: 300) + [codex[6]]).write(to: fixture.file)

        let small = try await Self.blocks(of: fixture.file, targetEntryCount: 7)
        let large = try await Self.blocks(of: fixture.file, targetEntryCount: 1_000)

        #expect(small == large)
        #expect(large.map(\.kind) == [.user, .toolRun, .assistant])
        #expect(large[1].toolCallCount == 300)
        #expect(large[1].lastRecord == 300)
        #expect(large[1].lineWidths.count == ConversationOutlineBuilder.maximumLinesPerToolRun)
    }

    @Test func lineWidthsWrapAt80ColumnsAndStopAt24Lines() {
        let width = ConversationOutlineBuilder.lineWidths(of:maximumLines:)
        #expect(width("a\n\n\n    code\n" + String(repeating: "x", count: 200), 24) == [1, 0, 8, 80, 80, 40])
        #expect(width(Array(repeating: "line", count: 100).joined(separator: "\n"), 24).count == 24)
        #expect(width(String(repeating: "z", count: 80) + "\ny", 24) == [80, 1])
        #expect(width("", 24) == [1])
        #expect(width("\n\nCafé ☕️\n\n", 24) == [7])
    }

    @Test func notesAreSkippedAndImagesKeepTheirPlace() {
        let image = SampleTranscriptImage.image
        var builder = ConversationOutlineBuilder()
        builder.append([
            Self.entry(0, .toolCalls(["Bash · swift build"])),
            Self.entry(1, .note("A record too large to show")),
            Self.entry(2, .toolCalls(["Read · Package.swift"])),
            Self.entry(3, .toolResultImage(image)),
            Self.entry(4, .userImage(image)),
            Self.entry(5, .userMessage("Look at this")),
        ])
        #expect(builder.blocks.map(\.kind) == [.toolRun, .image, .user])
        #expect(builder.blocks[0].toolCallCount == 2)
        #expect(builder.blocks[0].lastRecord == 3)
        #expect(builder.blocks[0].snippet == "Bash · swift build")
        #expect(builder.blocks[1].entryID == TranscriptPageIdentity.entryID(record: 4, part: 0))
    }

    @Test func aReplySnippetIsItsBookmarkSnippet() throws {
        let text =
            "Here is **the fix**, in `Parser.swift`:\n\n- read the [file](https://example.com)\n- change `parse()` so it keeps Café ☕️"
        let entry = Self.entry(1, .assistantMessage(text))
        var builder = ConversationOutlineBuilder()
        builder.append([entry])
        let snippet = try #require(MessageBookmarkNavigation.snippet(of: entry))
        #expect(!snippet.contains("**"))
        #expect(builder.blocks.first?.snippet == snippet)
    }

    @Test func theResumePointMovesBackOverABlockReachingIntoIt() {
        let blocks = [
            Self.block(record: 0, part: 0, lastRecord: 0, kind: .user),
            Self.block(record: 1, part: 0, lastRecord: 1, kind: .assistant),
            Self.block(record: 1, part: 1, lastRecord: 2, kind: .toolRun),
        ]
        let resume = ConversationOutlineBuilder.resumePoint(in: blocks)
        #expect(resume?.keptCount == 1)
        #expect(resume?.record == 1)
        #expect(ConversationOutlineBuilder.resumePoint(in: []) == nil)
    }

    /// A part shifts while an OpenCode message streams (MessageBookmarkNavigation.swift:45-47): the bookmark's chip
    /// follows its snippet within the record, as the reader's `locate` does, rather than whatever block now has its ID.
    @Test func aBookmarkFollowsItsSnippetWithinItsRecord() {
        let outline = ConversationOutline(blocks: [
            Self.block(record: 5, part: 0, lastRecord: 5, kind: .assistant, snippet: "Alpha"),
            Self.block(record: 5, part: 1, lastRecord: 5, kind: .toolRun, snippet: "Bash · ls"),
            Self.block(record: 5, part: 2, lastRecord: 5, kind: .assistant, snippet: "Beta"),
            Self.block(record: 5, part: 3, lastRecord: 5, kind: .assistant, snippet: "Gamma reply here, and more"),
        ])
        func bookmark(part: Int, _ snippet: String) -> MessageBookmark {
            MessageBookmark(letter: "a", entryID: TranscriptPageIdentity.entryID(record: 5, part: part), kind: .assistant, snippet: snippet)
        }
        #expect(outline.blockIndex(for: bookmark(part: 2, "Gamma reply here")) == 3)
        #expect(outline.blockIndex(for: bookmark(part: 1, "beta")) == 2)
        // A head that changed since keeps today's choice: its own ID, else the first block of its kind in the record.
        #expect(outline.blockIndex(for: bookmark(part: 2, "Delta")) == 2)
        #expect(outline.blockIndex(for: bookmark(part: 1, "Delta")) == 0)
    }

    private static func blocks(of file: URL, targetEntryCount: Int) async throws -> [Block] {
        var limits = ConversationOutlineReader.pageLimits(for: .codex)
        limits.targetEntryCount = targetEntryCount
        let source = TranscriptPageSource(file: file, provider: .codex, limits: limits)
        var builder = ConversationOutlineBuilder()
        var page = try await source.read(.first, preparesMarkdown: false)
        builder.append(page.entries)
        while page.hasLater {
            page = try await source.read(.after(page.records.upperBound), preparesMarkdown: false)
            builder.append(page.entries)
        }
        return builder.blocks
    }

    private static func entry(_ record: Int, _ content: TranscriptEntry.Content) -> TranscriptEntry {
        TranscriptEntry(id: TranscriptPageIdentity.entryID(record: record, part: 0), content: content, timestamp: nil, startsTurn: false)
    }

    private static func block(record: Int, part: Int, lastRecord: Int, kind: Block.Kind, snippet: String = "") -> Block {
        Block(
            entryID: TranscriptPageIdentity.entryID(record: record, part: part), lastRecord: lastRecord, kind: kind,
            timestamp: nil, snippet: snippet, lineWidths: [1], toolCallCount: kind == .toolRun ? 1 : 0)
    }
}
