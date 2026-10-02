import Foundation

/// A session that could not be deleted, with the reason its tool or host gave.
struct ConversationDeletionFailure: Sendable {
    let conversation: Conversation
    let reason: String
    /// The SSH host given up on, when that is why the session was not deleted.
    var unresponsiveHost: UnresponsiveSSHHost? = nil
    /// False when the session's file is gone anyway, so it left the list although its tool reported an error.
    var isStillListed = true
}
