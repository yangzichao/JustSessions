import Foundation

struct SessionDeletionPlan {
    let deletableConversations: [Conversation]
    let openTerminalCount: Int

    var hasDeletableConversations: Bool { !deletableConversations.isEmpty }
}
