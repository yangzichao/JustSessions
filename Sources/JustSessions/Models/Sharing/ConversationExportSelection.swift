import Foundation

/// Captures the displayed title when the user chooses Copy or Export.
struct ConversationExportSelection: Sendable {
    let conversation: Conversation
    let title: String
}
