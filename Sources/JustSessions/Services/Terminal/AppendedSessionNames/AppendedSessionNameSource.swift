import Foundation

/// Claude Code's `/rename` and Pi's `/name` append to the session's own file; Codex appends to its `session_index.jsonl`
/// whenever it names or renames a thread. Antigravity, Kiro CLI, and OpenCode keep their titles in a database or a file
/// they rewrite, so they have no lines to follow.
enum AppendedSessionNameSource {
    static func file(for conversation: Conversation, codexDirectory: URL) -> URL? {
        switch conversation.provider {
        case .claude, .pi: conversation.sourceFile
        case .codex: codexDirectory.appendingPathComponent("session_index.jsonl")
        case .antigravity, .kiro, .opencode: nil
        }
    }

    static func latestName(for conversation: Conversation, amongLines lines: [Data]) -> String? {
        guard let marker = nameLineMarker(of: conversation.provider) else { return nil }
        let nameLines = lines.filter { $0.range(of: marker) != nil }
        guard !nameLines.isEmpty else { return nil }
        let name: String? =
            switch conversation.provider {
            case .claude: ClaudeTranscriptTail(lines: nameLines).latestCustomTitle
            case .pi: PiSessionTitle.latestName(amongLines: nameLines)
            case .codex: CodexSessionIndex(lines: nameLines).entry(forSessionID: conversation.sessionID)?.threadName
            case .antigravity, .kiro, .opencode: nil
            }
        let cleanedName = ConversationMetadata.cleanTitle(name, fallback: "")
        return cleanedName.isEmpty ? nil : cleanedName
    }

    private static func nameLineMarker(of provider: ConversationProvider) -> Data? {
        switch provider {
        case .claude: Data("custom-title".utf8)
        case .pi: Data("session_info".utf8)
        case .codex: Data("thread_name".utf8)
        case .antigravity, .kiro, .opencode: nil
        }
    }
}
