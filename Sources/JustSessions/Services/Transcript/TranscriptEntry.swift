import Foundation

struct TranscriptEntry: Identifiable, Sendable, Equatable {
    enum Content: Sendable, Equatable {
        case userMessage(String)
        case assistantMessage(String)
        /// One-line summaries of consecutive tool calls, merged so a long agent run takes one row.
        case toolCalls([String])
        case note(String)
    }

    let id: Int
    let content: Content
    let timestamp: Date?
    /// First entry of a speaker's turn, where the preview shows "You" or the CLI's name.
    let startsTurn: Bool
}

struct TranscriptContent: Sendable, Equatable {
    let entries: [TranscriptEntry]
    /// Older entries left out so very long sessions stay responsive.
    let omittedEntryCount: Int
}
