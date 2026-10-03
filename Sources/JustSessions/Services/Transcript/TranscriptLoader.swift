import Foundation

enum TranscriptLoader {
    /// Nonisolated, so it runs off the main actor. Cancelling the calling task stops the read between chunks.
    static func load(
        _ conversation: Conversation,
        maximumEntryCount: Int = 2_000,
        maximumTextLength: Int = 12_000
    ) async throws -> TranscriptContent {
        switch conversation.provider {
        case .claude: try ClaudeTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile)
        case .codex: try CodexTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile)
        case .kiro: try KiroTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile)
        case .antigravity: try AntigravityTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile)
        case .pi: try PiTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile)
        case .opencode: try OpenCodeTranscriptReader(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength).read(conversation.sourceFile, sessionID: conversation.sessionID)
        }
    }
}
