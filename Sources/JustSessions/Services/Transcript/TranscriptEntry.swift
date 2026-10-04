import Foundation

struct TranscriptEntry: Identifiable, Sendable, Equatable {
    enum Content: Sendable, Equatable {
        case userMessage(String)
        case assistantMessage(String)
        /// One-line summaries of consecutive tool calls, merged so a long agent run takes one row.
        case toolCalls([String])
        case note(String)
        /// An image the user attached to a message.
        case userImage(TranscriptImage)
        /// An image a tool returned, such as a screenshot, shown after the tool call that produced it.
        case toolResultImage(TranscriptImage)
    }

    let id: Int
    let content: Content
    let timestamp: Date?
    /// First entry of a speaker's turn, where the preview shows "You" or the CLI's name.
    let startsTurn: Bool
    /// Display preparation is absent for full-fidelity exports, which do not need rendered Markdown.
    var markdown: PreparedTranscriptMarkdown? = nil
}
