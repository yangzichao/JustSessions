import Foundation

extension Conversation {
    /// Listed before its first prompt, under the title its tool's sessions get until then. A refresh after the first
    /// prompt titles it; see new session discovery.
    var isAwaitingFirstPromptTitle: Bool {
        suggestedTitle == ConversationMetadata.untitledConversationTitle
            || (provider == .antigravity && suggestedTitle == AntigravityAdapter.fallbackTitle(forSessionID: sessionID))
    }
}
