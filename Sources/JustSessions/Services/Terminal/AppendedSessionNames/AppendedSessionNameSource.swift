import Foundation

/// Where a CLI appends a line naming a session as the name changes, and how to read the name from such lines. Claude
/// Code's `/rename` and Pi's `/name` append to the session's own file; Codex appends to its `session_index.jsonl`
/// whenever it names or renames a thread. Antigravity, Kiro CLI, and OpenCode keep their titles in a database or a
/// file they rewrite, so they have no lines to follow.
enum AppendedSessionNameSource {
    /// The file whose new lines may rename `conversation`'s session; nil for a tool that appends no names.
    static func file(for conversation: Conversation, codexDirectory: URL) -> URL? {
        switch conversation.provider {
        case .claude, .pi: conversation.sourceFile
        case .codex: codexDirectory.appendingPathComponent("session_index.jsonl")
        case .antigravity, .kiro, .opencode: nil
        }
    }

    /// The latest name `lines` give `conversation`'s session, cleaned as a listed title is; `lines` are oldest first.
    static func latestName(for conversation: Conversation, amongLines lines: [Data]) -> String? {
        guard let marker = nameLineMarker(of: conversation.provider) else { return nil }
        // Most appended lines are the conversation itself, so only lines that can name the session are parsed.
        let nameLines = lines.filter { $0.range(of: marker) != nil }
        guard !nameLines.isEmpty else { return nil }
        let name: String? = switch conversation.provider {
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
