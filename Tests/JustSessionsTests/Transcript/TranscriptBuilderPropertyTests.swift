import Testing
@testable import JustSessions

/// Random sequences of appends. Whatever the sequence, the built transcript keeps the rules the preview relies on.
struct TranscriptBuilderPropertyTests {
    private enum Step {
        case append(TranscriptBuilder.EntryKind, String)
        case compaction
    }

    private static let texts = ["", "  ", "\n", "hello", "  padded  ", "line one\nline two", String(repeating: "long ", count: 10), "é 🚀 中"]
    private static let maximumTextLength = 20

    @Test(arguments: [(UInt64(1), 50), (2, 5), (3, 1), (4, 10_000), (5, 3), (6, 120)])
    func builtTranscriptsKeepTheirRules(seed: UInt64, maximumEntryCount: Int) {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let steps = (0..<300).map { _ in Self.randomStep(using: &generator) }

        let transcript = Self.build(steps, maximumEntryCount: maximumEntryCount)
        let fullTranscript = Self.build(steps, maximumEntryCount: .max)

        #expect(transcript.entries.count == min(fullTranscript.entries.count, maximumEntryCount))
        #expect(transcript.omittedEntryCount == fullTranscript.entries.count - transcript.entries.count)
        #expect(transcript.entries.map(\.content) == fullTranscript.entries.suffix(transcript.entries.count).map(\.content))
        #expect(transcript.entries.map(\.id) == Array(transcript.entries.indices))

        var previousEntry: TranscriptEntry?
        for entry in transcript.entries {
            let isToolCallRun = if case .toolCalls = entry.content { true } else { false }
            let followsToolCallRun = if case .toolCalls = previousEntry?.content { true } else { false }
            #expect(!(isToolCallRun && followsToolCallRun), "consecutive tool calls share one entry")
            let expectedStartsTurn = Self.speaker(of: entry) != nil && Self.speaker(of: entry) != previousEntry.flatMap(Self.speaker)
            #expect(entry.startsTurn == expectedStartsTurn)
            for text in Self.texts(of: entry) {
                #expect(!text.isEmpty && !text.first!.isWhitespace)
                #expect(text.count <= Self.maximumTextLength + 2)
            }
            previousEntry = entry
        }

        let appendedToolCallCount = steps.filter {
            if case .append(.toolCall, let text) = $0 { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } else { false }
        }.count
        let shownToolCallCount = fullTranscript.entries.map { if case .toolCalls(let summaries) = $0.content { summaries.count } else { 0 } }
            .reduce(0, +)
        #expect(shownToolCallCount == appendedToolCallCount)
    }

    private static func randomStep(using generator: inout SeededRandomNumberGenerator) -> Step {
        let kinds: [TranscriptBuilder.EntryKind] = [.userMessage, .assistantMessage, .toolCall, .toolCall, .note]
        guard Int.random(in: 0..<20, using: &generator) != 0 else { return .compaction }
        return .append(kinds.randomElement(using: &generator)!, texts.randomElement(using: &generator)!)
    }

    private static func build(_ steps: [Step], maximumEntryCount: Int) -> TranscriptContent {
        var builder = TranscriptBuilder(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength)
        for step in steps {
            switch step {
            case .append(let kind, let text): builder.append(kind, text: text, timestamp: nil)
            case .compaction: builder.appendCompactionNote(timestamp: nil)
            }
        }
        return builder.build()
    }

    private enum Speaker { case user, assistant }

    private static func speaker(of entry: TranscriptEntry) -> Speaker? {
        switch entry.content {
        case .userMessage: .user
        case .assistantMessage, .toolCalls: .assistant
        case .note: nil
        }
    }

    private static func texts(of entry: TranscriptEntry) -> [String] {
        switch entry.content {
        case .userMessage(let text), .assistantMessage(let text), .note(let text): [text]
        case .toolCalls(let summaries): summaries
        }
    }
}
