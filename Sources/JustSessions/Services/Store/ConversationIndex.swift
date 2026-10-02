import Foundation

/// The listed sessions by id and by project, built again whenever the list changes, so a sidebar row finds its own
/// sessions without going through every listed one.
struct ConversationIndex {
    private let conversationsByID: [String: Conversation]
    private let conversationsByProjectKey: [String: [Conversation]]

    /// Each project keeps its sessions in list order. When two share an id, the first one listed wins.
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
