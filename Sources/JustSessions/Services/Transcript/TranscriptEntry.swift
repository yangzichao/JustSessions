import Foundation

struct TranscriptEntry: Identifiable, Sendable, Equatable {
    enum Content: Sendable, Equatable {
        case userMessage(String)
        case assistantMessage(String)
        case toolCalls([String])
        case note(String)
        case userImage(TranscriptImage)
        case toolResultImage(TranscriptImage)
    }

    let id: Int
    let content: Content
    let timestamp: Date?
    let startsTurn: Bool
    var markdown: PreparedTranscriptMarkdown? = nil
}
