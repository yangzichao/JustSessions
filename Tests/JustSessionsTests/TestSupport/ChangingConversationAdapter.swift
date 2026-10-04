import Foundation
@testable import JustSessions

/// Claude Code sessions a test can add to between refreshes, as a running CLI writes new ones.
final class ChangingConversationAdapter: ConversationAdapter, @unchecked Sendable {
    let provider: ConversationProvider = .claude
    private let lock = NSLock()
    private var conversations: [Conversation] = []

    func add(_ conversation: Conversation) {
        lock.withLock { conversations.append(conversation) }
    }

    func discover() throws -> [Conversation] {
        lock.withLock { conversations }
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
    func delete(_ conversation: Conversation) throws {}
}
