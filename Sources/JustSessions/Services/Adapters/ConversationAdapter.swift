import Foundation

protocol ConversationAdapter: Sendable {
    var provider: ConversationProvider { get }
    func discover() throws -> [Conversation]
    func arguments(for conversation: Conversation, action: ConversationAction) -> [String]
    func delete(_ conversation: Conversation) throws
}
