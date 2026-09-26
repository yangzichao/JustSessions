import Foundation
@testable import JustSessions

/// Lists a fixed set of Claude Code conversations and never deletes anything.
struct StaticConversationAdapter: ConversationAdapter {
    let provider: ConversationProvider = .claude
    let discoveredConversations: [Conversation]

    func discover() throws -> [Conversation] { discoveredConversations }
    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
    func delete(_ conversation: Conversation) throws {}
}
