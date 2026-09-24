import Foundation

struct SessionDeletionPlan {
    let deletableConversations: [Conversation]
    let openTerminalCount: Int
    let unsupportedCount: Int

    var hasDeletableConversations: Bool { !deletableConversations.isEmpty }
}
