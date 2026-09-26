import Foundation

/// A session that could not be deleted, with the reason its tool or host gave.
struct ConversationDeletionFailure: Sendable {
    let conversation: Conversation
    let reason: String

    /// What is shown after deleting one session: the reason alone, since the user just picked the session.
    static func messageAfterDeletingOneSession(_ failures: [ConversationDeletionFailure]) -> String {
        failures.map(\.reason).joined(separator: "\n")
    }

    /// What is shown after deleting several sessions: which ones failed, and why.
    static func messageAfterDeletingSeveralSessions(_ failures: [ConversationDeletionFailure]) -> String {
        "Some sessions could not be deleted:\n" + failures.map {
            "\($0.conversation.provider.rawValue) · \($0.conversation.suggestedTitle): \($0.reason)"
        }.joined(separator: "\n")
    }
}
