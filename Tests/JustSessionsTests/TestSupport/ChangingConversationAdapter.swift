import Foundation
@testable import JustSessions

/// Sessions of one tool that a test can add to between refreshes, as a running CLI writes new ones.
final class ChangingConversationAdapter: ConversationAdapter, @unchecked Sendable {
    let provider: ConversationProvider
    private let lock = NSLock()
    private var conversations: [Conversation] = []

    init(provider: ConversationProvider) {
        self.provider = provider
    }

    func add(_ conversation: Conversation) {
        lock.withLock { conversations.append(conversation) }
    }

    func discover() throws -> [Conversation] {
        lock.withLock { conversations }
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
    func delete(_ conversation: Conversation) throws {}
}
