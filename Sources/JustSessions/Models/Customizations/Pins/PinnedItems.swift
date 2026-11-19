import Foundation

struct PinnedItems: Equatable {
    static let projectPathsUserDefaultsKey = "pinnedProjectPaths"
    static let conversationIDsUserDefaultsKey = "pinnedConversationIDs"

    private var pinnedProjects: PinnedOrder
    private var pinnedConversations: PinnedOrder

    init(pinnedProjectPaths: [String] = [], pinnedConversationIDs: [String] = []) {
        pinnedProjects = PinnedOrder(pinnedProjectPaths)
        pinnedConversations = PinnedOrder(pinnedConversationIDs)
    }

    var pinnedProjectPaths: [String] { pinnedProjects.ids }
    var pinnedConversationIDs: [String] { pinnedConversations.ids }

    static func load(from userDefaults: UserDefaults) -> PinnedItems {
        PinnedItems(
            pinnedProjectPaths: userDefaults.stringArray(forKey: projectPathsUserDefaultsKey) ?? [],
            pinnedConversationIDs: userDefaults.stringArray(forKey: conversationIDsUserDefaultsKey) ?? []
        )
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(pinnedProjectPaths, forKey: Self.projectPathsUserDefaultsKey)
        userDefaults.set(pinnedConversationIDs, forKey: Self.conversationIDsUserDefaultsKey)
    }

    func isPinned(projectPath: String) -> Bool {
        pinnedProjects.contains(projectPath)
    }

    func isPinned(conversationID: String) -> Bool {
        pinnedConversations.contains(conversationID)
    }

    func pinnedPlace(ofProjectPath projectPath: String) -> Int? {
        pinnedProjects.place(of: projectPath)
    }

    mutating func setPinned(_ isPinned: Bool, projectPath: String) {
        if isPinned { pinnedProjects.pin(projectPath) } else { pinnedProjects.unpin(projectPath) }
    }

    mutating func setPinned(_ isPinned: Bool, conversationID: String) {
        if isPinned { pinnedConversations.pin(conversationID) } else { pinnedConversations.unpin(conversationID) }
    }

    mutating func movePinnedProject(_ projectPath: String, to placement: PinnedPlacement) {
        pinnedProjects.move(projectPath, to: placement)
    }

    mutating func movePinnedConversation(_ conversationID: String, to placement: PinnedPlacement) {
        pinnedConversations.move(conversationID, to: placement)
    }

    func pinnedConversationsFirst(_ conversations: [Conversation]) -> [Conversation] {
        let pinned =
            conversations
            .compactMap { conversation in pinnedConversations.place(of: conversation.id).map { (conversation, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
        return pinned + conversations.filter { !isPinned(conversationID: $0.id) }
    }
}
