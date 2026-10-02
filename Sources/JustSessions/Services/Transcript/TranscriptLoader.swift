import Foundation

enum TranscriptLoader {
    static func supportsReading(_ provider: ConversationProvider) -> Bool {
        switch provider {
        case .claude, .codex, .kiro, .antigravity, .pi: true
        case .opencode: false
        }
    }

    /// Nonisolated, so it runs off the main actor. Cancelling the calling task stops the read between chunks.
    static func load(
        _ conversation: Conversation,
        maximumEntryCount: Int = 2_000,
        maximumTextLength: Int = 12_000
    ) async throws -> TranscriptLoadResult {
        switch conversation.provider {
        case .claude: .loaded(try ClaudeTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile))
        case .codex: .loaded(try CodexTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile))
        case .kiro: .loaded(try KiroTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile))
        case .antigravity: .loaded(try AntigravityTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile))
        case .pi: .loaded(try PiTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile))
        case .opencode: .unsupported
        }
    }
}
