import Foundation

enum TranscriptLoader {
    /// Nonisolated, so it runs off the main actor. Cancelling the calling task stops the read between chunks.
    static func load(_ conversation: Conversation) async throws -> TranscriptLoadResult {
        switch conversation.provider {
        case .claude: .loaded(try ClaudeTranscriptReader().read(conversation.sourceFile))
        case .codex: .loaded(try CodexTranscriptReader().read(conversation.sourceFile))
        case .kiro: .loaded(try KiroTranscriptReader().read(conversation.sourceFile))
        case .antigravity, .opencode, .pi: .unsupported
        }
    }
}
