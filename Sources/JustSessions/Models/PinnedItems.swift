import Foundation

/// Projects and sessions pinned to the top of their lists.
/// Projects are keyed by `projectDirectoryKey`, sessions by `Conversation.id`.
struct PinnedItems: Equatable {
    static let projectPathsUserDefaultsKey = "pinnedProjectPaths"
    static let conversationIDsUserDefaultsKey = "pinnedConversationIDs"

    private(set) var pinnedProjectPaths: Set<String>
    private(set) var pinnedConversationIDs: Set<String>

    init(pinnedProjectPaths: Set<String> = [], pinnedConversationIDs: Set<String> = []) {
        self.pinnedProjectPaths = pinnedProjectPaths
        self.pinnedConversationIDs = pinnedConversationIDs
    }

    static func load(from userDefaults: UserDefaults) -> PinnedItems {
        PinnedItems(
            pinnedProjectPaths: Set(userDefaults.stringArray(forKey: projectPathsUserDefaultsKey) ?? []),
            pinnedConversationIDs: Set(userDefaults.stringArray(forKey: conversationIDsUserDefaultsKey) ?? [])
        )
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(pinnedProjectPaths.sorted(), forKey: Self.projectPathsUserDefaultsKey)
        userDefaults.set(pinnedConversationIDs.sorted(), forKey: Self.conversationIDsUserDefaultsKey)
    }

    func isPinned(projectPath: String) -> Bool {
        pinnedProjectPaths.contains(projectPath)
    }

    func isPinned(conversationID: String) -> Bool {
        pinnedConversationIDs.contains(conversationID)
    }

    mutating func setPinned(_ isPinned: Bool, projectPath: String) {
        if isPinned { pinnedProjectPaths.insert(projectPath) } else { pinnedProjectPaths.remove(projectPath) }
    }

    mutating func setPinned(_ isPinned: Bool, conversationID: String) {
        if isPinned { pinnedConversationIDs.insert(conversationID) } else { pinnedConversationIDs.remove(conversationID) }
    }

    /// Moves pinned conversations to the front; each part keeps its incoming order.
    func pinnedConversationsFirst(_ conversations: [Conversation]) -> [Conversation] {
        conversations.filter { isPinned(conversationID: $0.id) } + conversations.filter { !isPinned(conversationID: $0.id) }
    }
}
