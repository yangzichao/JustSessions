import Foundation
import Testing
@testable import JustSessions

struct ClaudeTranscriptTailTests {
    @Test func readsTheLastTimestampAndTheLastCustomTitle() {
        let tail = ClaudeTranscriptTail(lines: jsonLines([
            #"{"type":"custom-title","customTitle":"First name","timestamp":"2026-09-24T10:00:00Z"}"#,
            #"{"type":"custom-title","customTitle":"Second name"}"#,
            #"{"type":"user","timestamp":"2026-09-24T11:00:00Z","message":{"content":"Keep going"}}"#,
            #"{"type":"summary","summary":"No timestamp here"}"#,
            "not json",
        ]))

        #expect(tail.latestTimestamp == ConversationMetadata.date("2026-09-24T11:00:00Z"))
        #expect(tail.latestCustomTitle == "Second name")
    }

    @Test func aTranscriptWithNeitherSaysNothing() {
        let tail = ClaudeTranscriptTail(lines: jsonLines([#"{"type":"user","message":{"content":"Hi"}}"#]))

        #expect(tail.latestTimestamp == nil)
        #expect(tail.latestCustomTitle == nil)
    }

    @Test func onlyTheEndOfALongTranscriptIsRead() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("\(UUID().uuidString).jsonl")
        let filler = String(repeating: #"{"type":"assistant"}"# + "\n", count: 13_000)
        #expect(filler.utf8.count > ClaudeTranscriptTail.maximumByteCount)
        let earlyTitle = #"{"type":"custom-title","customTitle":"Early name"}"# + "\n"
        let lastLine = #"{"type":"user","timestamp":"2026-09-24T11:00:00Z"}"# + "\n"
        try (earlyTitle + filler + lastLine).write(to: file, atomically: true, encoding: .utf8)

        let tail = ClaudeTranscriptTail(file: file)
        #expect(tail.latestCustomTitle == nil)
        #expect(tail.latestTimestamp == ConversationMetadata.date("2026-09-24T11:00:00Z"))
    }
}
