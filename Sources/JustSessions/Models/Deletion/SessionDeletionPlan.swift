import Foundation

struct SessionDeletionPlan {
    let deletableConversations: [Conversation]
    let openTerminalCount: Int
    var cliEndingCount = 0
    var deletedSubagentCount = 0
    var keptSubagentCount = 0

    var hasDeletableConversations: Bool { !deletableConversations.isEmpty }
}
