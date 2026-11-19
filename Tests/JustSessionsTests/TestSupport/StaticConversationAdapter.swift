import Foundation

@testable import JustSessions

struct StaticConversationAdapter: ConversationAdapter {
    let provider: ConversationProvider = .claude
    let discoveredConversations: [Conversation]

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        try cancellation.checkCancellation()
        return discoveredConversations
    }
    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
    func delete(_ conversation: Conversation) throws {}
}
