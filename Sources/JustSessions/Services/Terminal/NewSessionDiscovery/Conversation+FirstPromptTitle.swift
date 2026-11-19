import Foundation

extension Conversation {
    var isAwaitingFirstPromptTitle: Bool {
        suggestedTitle == ConversationMetadata.untitledConversationTitle
            || (provider == .antigravity && suggestedTitle == AntigravityAdapter.fallbackTitle(forSessionID: sessionID))
    }
}
