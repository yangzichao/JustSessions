import Foundation

struct SessionDeletionPlan {
    let deletableConversations: [Conversation]
    let openTerminalCount: Int
    /// Subagent sessions, at any depth, that go with the deletable sessions; see `deletesSubagentsWithSession`.
    var deletedSubagentCount = 0
    /// Subagent sessions that stay on disk when the sessions that started them are deleted.
    var keptSubagentCount = 0

    var hasDeletableConversations: Bool { !deletableConversations.isEmpty }
}
