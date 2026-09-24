import Foundation

struct ProjectSessionDeletionPlan {
    let projectPath: String
    let deletableConversations: [Conversation]
    let openTerminalCount: Int
    let unsupportedCount: Int

    var hasDeletableConversations: Bool { !deletableConversations.isEmpty }
}
