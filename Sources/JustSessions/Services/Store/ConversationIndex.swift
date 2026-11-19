import Foundation

struct ConversationIndex {
    private let conversationsByID: [String: Conversation]
    private let conversationsByProjectKey: [String: [Conversation]]

    init(_ conversations: [Conversation]) {
        conversationsByID = Dictionary(conversations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        conversationsByProjectKey = Dictionary(grouping: conversations, by: \.projectDirectoryKey)
    }

    func conversation(withID conversationID: String) -> Conversation? {
        conversationsByID[conversationID]
    }

    func conversations(inProject projectDirectoryKey: String) -> [Conversation] {
        conversationsByProjectKey[projectDirectoryKey] ?? []
    }
}
