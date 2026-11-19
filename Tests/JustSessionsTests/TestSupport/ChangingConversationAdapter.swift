import Foundation

@testable import JustSessions

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

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        try cancellation.checkCancellation()
        return lock.withLock { conversations }
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
    func delete(_ conversation: Conversation) throws {}
}
