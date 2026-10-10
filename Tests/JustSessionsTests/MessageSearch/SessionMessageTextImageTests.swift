import Foundation
import Testing
@testable import JustSessions

/// Message search reads sessions only for their text, so it never decodes an image's base64 or reads its header. Each
/// image still keeps its entry, so every other entry has the id the reader gives it, and a match opens in the right
/// place.
struct SessionMessageTextImageTests {
    private static let image = SampleTranscriptImage.base64

    static let samples: [(ConversationProvider, [String])] = [
        (.claude, [
            #"{"type":"user","timestamp":"2026-09-24T10:00:00.000Z","message":{"role":"user","content":[{"type":"text","text":"What is in this?"},{"type":"image","source":{"type":"base64","media_type":"image/png","data":"\#(image)"}}]}}"#,
            #"{"type":"assistant","timestamp":"2026-09-24T10:00:01.000Z","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/diagram.png"}}]}}"#,
            #"{"type":"user","timestamp":"2026-09-24T10:00:02.000Z","message":{"role":"user","content":[{"type":"tool_result","content":[{"type":"text","text":"hidden caption"},{"type":"image","source":{"type":"base64","media_type":"image/png","data":"\#(image)"}}]}]}}"#,
            #"{"type":"assistant","timestamp":"2026-09-24T10:00:03.000Z","message":{"role":"assistant","content":"A red diagram."}}"#,
        ]),
        (.codex, [
            #"{"timestamp":"2026-09-24T10:00:00.000Z","type":"session_meta","payload":{"id":"abc","cwd":"/tmp"}}"#,
            #"{"timestamp":"2026-09-24T10:00:01.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"What is in this?"},{"type":"input_image","image_url":"data:image/png;base64,\#(image)"}]}}"#,
            #"{"timestamp":"2026-09-24T10:00:02.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"A red diagram."}]}}"#,
            #"{"timestamp":"2026-09-24T10:00:03.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_image","image_url":"data:image/png;base64,\#(image)"}]}}"#,
            #"{"timestamp":"2026-09-24T10:00:04.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Another one."}]}}"#,
        ]),
        (.pi, [
            #"{"type":"session","version":3,"id":"019a0000-0000-7000-8000-000000000000","timestamp":"2026-09-24T10:00:00.000Z","cwd":"/tmp"}"#,
            #"{"type":"message","id":"a1","parentId":null,"timestamp":"2026-09-24T10:00:01.000Z","message":{"role":"user","content":[{"type":"text","text":"What is in this?"},{"type":"image","data":"\#(image)","mimeType":"image/png"}],"timestamp":1758708001000}}"#,
            #"{"type":"message","id":"a2","parentId":"a1","timestamp":"2026-09-24T10:00:02.000Z","message":{"role":"assistant","content":[{"type":"toolCall","id":"t1","name":"screenshot","arguments":{}}],"stopReason":"toolUse","timestamp":1758708002000}}"#,
            #"{"type":"message","id":"a3","parentId":"a2","timestamp":"2026-09-24T10:00:03.000Z","message":{"role":"toolResult","toolCallId":"t1","toolName":"screenshot","content":[{"type":"image","data":"\#(image)","mimeType":"image/png"}],"isError":false,"timestamp":1758708003000}}"#,
            #"{"type":"message","id":"a4","parentId":"a3","timestamp":"2026-09-24T10:00:04.000Z","message":{"role":"assistant","content":[{"type":"text","text":"A red diagram."}],"stopReason":"stop","timestamp":1758708004000}}"#,
        ]),
    ]

    @Test(arguments: samples)
    func readingOnlyTextKeepsEveryEntryButLeavesImagesUndecoded(provider: ConversationProvider, lines: [String]) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try SampleTranscriptLines.fileContents(lines).write(to: file)

        let full = try await TranscriptPageSource(file: file, provider: provider).read(.first)
        let textOnly = try await TranscriptPageSource(file: file, provider: provider, readsImageData: false).read(.first)

        let fullImages = full.entries.compactMap(\.image)
        #expect(fullImages.count == 2)
        #expect(fullImages.allSatisfy { $0 == SampleTranscriptImage.image })
        #expect(textOnly.entries.compactMap(\.image) == [.unread, .unread])
        #expect(textOnly.entries.map(\.id) == full.entries.map(\.id))
        #expect(textOnly.entries.filter { $0.image == nil } == full.entries.filter { $0.image == nil })
        #expect(textOnly.records == full.records)
    }

    @Test(arguments: samples)
    func searchFindsWhatTheReaderShowsAroundImages(provider: ConversationProvider, lines: [String]) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try SampleTranscriptLines.fileContents(lines).write(to: file)
        let conversation = Conversation.fixture(provider: provider, sourceFile: file)

        let text = try await SessionMessageTextReader.read(conversation)

        let page = try await TranscriptPageSource(file: file, provider: provider).read(.first)
        let expectedEntries = page.entries.compactMap { entry -> SessionMessageText.Entry? in
            switch entry.content {
            case .note, .userImage, .toolResultImage: nil
            default: SessionMessageText.Entry(id: entry.id, segments: TranscriptSearchSegments.texts(in: entry))
            }
        }
        #expect(text.entries == expectedEntries)
        #expect(text.entries.flatMap(\.segments).contains { $0.contains("A red diagram.") })
    }
}

private extension TranscriptEntry {
    var image: TranscriptImage? {
        switch content {
        case .userImage(let image), .toolResultImage(let image): image
        default: nil
        }
    }
}
