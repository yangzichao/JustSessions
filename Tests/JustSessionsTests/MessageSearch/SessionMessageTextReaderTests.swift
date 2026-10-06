import Foundation
import Testing
@testable import JustSessions

struct SessionMessageTextReaderTests {
    static let samples: [(ConversationProvider, [String])] = [
        (.claude, SampleTranscriptLines.claude),
        (.codex, SampleTranscriptLines.codex),
        (.kiro, KiroTranscriptSamples.lines),
        (.pi, SampleTranscriptLines.pi),
    ]

    @Test(arguments: samples)
    func keepsTheReadersEntriesWithFindsSegmentsLeavingOutNotesAndImages(provider: ConversationProvider, lines: [String]) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try SampleTranscriptLines.fileContents(lines).write(to: file)
        let conversation = Conversation.fixture(provider: provider, sourceFile: file)

        let text = try await SessionMessageTextReader.read(conversation)

        let page = try await TranscriptPageSource(file: file, provider: provider, sessionID: conversation.sessionID).read(.first)
        let expectedEntries = page.entries.compactMap { entry -> SessionMessageText.Entry? in
            switch entry.content {
            case .note, .userImage, .toolResultImage: nil
            default: SessionMessageText.Entry(id: entry.id, segments: TranscriptSearchSegments.texts(in: entry))
            }
        }
        #expect(!page.hasLater)
        #expect(!expectedEntries.isEmpty)
        #expect(text.entries == expectedEntries)
    }

    @Test func readsEveryPageOfALongSession() async throws {
        let files = try TranscriptPagingFixture(count: 500)
        defer { files.remove() }

        let text = try await SessionMessageTextReader.read(
            files.conversation, limits: TranscriptPageLimits(targetEntryCount: 7, maximumRecordCount: 256, targetByteCount: 1 << 20)
        )

        #expect(text.entries.map(\.id) == (0..<500).map { TranscriptPageIdentity.entryID(record: $0, part: 0) })
        #expect(text.entries.last?.segments.first?.hasPrefix("Message 499, line 0") == true)
    }

    @Test func keepsOnlyTheTextTheReaderShowsOfALongMessage() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        let longText = String(repeating: "a", count: TranscriptPageLimits().maximumTextLength) + " past the reader's cut"
        try SampleTranscriptLines.fileContents([
            #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"\#(longText)"}]}}"#,
        ]).write(to: file)

        let text = try await SessionMessageTextReader.read(.fixture(provider: .codex, sourceFile: file))

        let segments = text.entries.flatMap(\.segments)
        #expect(!segments.isEmpty)
        #expect(!segments.contains { $0.contains("past the reader's cut") })
    }

    @Test func aMissingSessionFileFailsTheRead() async {
        let conversation = Conversation.fixture(provider: .codex, sourceFile: URL(fileURLWithPath: "/tmp/justsessions-tests/missing-\(UUID()).jsonl"))
        await #expect(throws: (any Error).self) { try await SessionMessageTextReader.read(conversation) }
    }
}
