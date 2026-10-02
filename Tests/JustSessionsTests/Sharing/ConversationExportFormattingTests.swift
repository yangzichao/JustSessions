import Foundation
import Testing
@testable import JustSessions

struct ConversationExportFormattingTests {
    @Test func preservesRolesCodeImagesNotesAndToolSummariesAcrossBothFileFormats() async throws {
        let document = makeDocument()
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for format: ConversationExportFormat in [.markdown, .plainText] {
            let text = try await document.text(in: format)
            #expect(text.contains("你好\n\n[Image]"))
            #expect(text.contains("```swift\nprint(\"🙂\")\n```"))
            #expect(text.contains("Tool calls (summaries)"))
            #expect(text.contains("shell · echo ```"))
            #expect(text.contains(TranscriptBuilder.compactionNoteText))
            #expect(text.contains("2026-10-02T12:00:00Z"))
            #expect(text.contains("Session ID: session-id"))
            if format == .markdown {
                #expect(text.contains("## You"))
                #expect(text.contains("## Codex"))
                #expect(text.contains("````\nshell · echo ```\nread · file.swift\n````"))
            } else {
                #expect(!text.contains("## You"))
                #expect(!text.contains("````"))
            }
            let destination = directory.appendingPathComponent(document.suggestedFileName(for: format))
            try "Existing file".write(to: destination, atomically: true, encoding: .utf8)
            try await document.write(to: destination, format: format)
            #expect(try String(contentsOf: destination, encoding: .utf8) == text)
        }
    }

    @Test func batchExportKeepsSelectionOrderAndEachSessionMetadata() async throws {
        let first = makeDocument(title: "First").sessions[0]
        let second = makeDocument(title: "Second").sessions[0]
        let document = ConversationExportDocument(sessions: [first, second])
        let text = try await document.text(in: .markdown)
        #expect(text.hasPrefix("# First\n"))
        #expect(text.contains("\n\n---\n\n# Second\n"))
        #expect(document.suggestedFileName(for: .markdown) == "Conversations.md")
    }

    @Test func suggestedFileNamesKeepUnicodeAndRemovePathSeparatorsAndControlCharacters() {
        #expect(makeDocument(title: " ../你好:build/日志\n ").suggestedFileName(for: .markdown) == "-你好-build-日志-.md")
        #expect(makeDocument(title: " ... ").suggestedFileName(for: .plainText) == "Conversation.txt")
        let longName = makeDocument(title: String(repeating: "界", count: 200)).suggestedFileName(for: .markdown)
        #expect(longName == String(repeating: "界", count: 100) + ".md")
    }

    private func makeDocument(title: String = "对话") -> ConversationExportDocument {
        let timestamp = ISO8601TimestampParser.shared.date(from: "2026-10-02T12:00:00Z")!
        let selection = ConversationExportSelection(
            conversation: .fixture(provider: .codex, sessionID: "session-id", updatedAt: timestamp), title: title
        )
        let contents: [TranscriptEntry.Content] = [
            .userMessage("你好\n\n[Image]"),
            .assistantMessage("```swift\nprint(\"🙂\")\n```"),
            .toolCalls(["shell · echo ```", "read · file.swift"]),
            .note(TranscriptBuilder.compactionNoteText),
        ]
        let transcript = TranscriptContent(entries: contents.enumerated().map { index, content in
            TranscriptEntry(id: index, content: content, timestamp: timestamp, startsTurn: true)
        }, omittedEntryCount: 0)
        return ConversationExportDocument(sessions: [.init(selection: selection, transcript: transcript)])
    }
}
