import Foundation

struct ConversationDeletionFailure: Sendable {
    let conversation: Conversation
    let reason: String
    var unresponsiveHost: UnresponsiveSSHHost? = nil
    var isStillListed = true
}
