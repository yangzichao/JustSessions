import Foundation

struct AntigravityConversationSummary {
    let title: String?
    let preview: String?
    let projectPath: String?
    let updatedAt: Date?
    /// The conversation that started this one as a subagent; nil for one started on its own.
    var parentConversationID: String? = nil
}
