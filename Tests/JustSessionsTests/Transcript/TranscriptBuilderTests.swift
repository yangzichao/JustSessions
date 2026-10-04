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

    /// A user's image stays in their turn, and a tool's image stays in the assistant's, so neither repeats the
    /// speaker. An image between tool calls keeps them apart, so it shows after the call that produced it.
    @Test func imagesContinueTheirSpeakersTurnAndSeparateToolCalls() {
        var builder = TranscriptBuilder()
        builder.append(.userMessage, text: "Look", timestamp: nil)
        builder.appendUserImage(SampleTranscriptImage.image, timestamp: nil)
        builder.append(.toolCall, text: "screenshot", timestamp: nil)
        builder.appendToolResultImage(SampleTranscriptImage.image, timestamp: nil)
        builder.append(.toolCall, text: "Bash · ls", timestamp: nil)
        builder.appendUserImage(SampleTranscriptImage.image, timestamp: nil)

        let transcript = builder.build()

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Look"),
            .userImage(SampleTranscriptImage.image),
            .toolCalls(["screenshot"]),
            .toolResultImage(SampleTranscriptImage.image),
            .toolCalls(["Bash · ls"]),
            .userImage(SampleTranscriptImage.image),
        ])
        #expect(transcript.entries.map(\.startsTurn) == [true, false, true, false, false, true])
    }
}
