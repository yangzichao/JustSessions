import Foundation
import Testing
@testable import JustSessions

struct TranscriptBuilderTests {
    @Test func keepsNewestEntriesAndTruncatesLongText() {
        var builder = TranscriptBuilder(maximumEntryCount: 2, maximumTextLength: 5)
        builder.append(.userMessage, text: "first", timestamp: nil)
        builder.append(.assistantMessage, text: "second", timestamp: nil)
        builder.append(.userMessage, text: "   ", timestamp: nil)
        builder.append(.userMessage, text: "third", timestamp: nil)

        let transcript = builder.build()

        #expect(transcript.omittedEntryCount == 1)
        #expect(transcript.entries.map(\.content) == [.assistantMessage("secon\n…"), .userMessage("third")])
        #expect(transcript.entries.map(\.id) == [0, 1])
        #expect(transcript.entries.map(\.startsTurn) == [true, true])
    }

    @Test func notesBreakToolCallRunsAndRestartTurns() {
        var builder = TranscriptBuilder()
        builder.append(.toolCall, text: "Bash · ls", timestamp: nil)
        builder.append(.note, text: "Earlier messages were compacted", timestamp: nil)
        builder.append(.toolCall, text: "Read · a.swift", timestamp: nil)

        let transcript = builder.build()

        #expect(transcript.entries.map(\.content) == [
            .toolCalls(["Bash · ls"]),
            .note("Earlier messages were compacted"),
            .toolCalls(["Read · a.swift"]),
        ])
        #expect(transcript.entries.map(\.startsTurn) == [true, false, true])
    }
}
