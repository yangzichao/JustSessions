import Foundation

/// Projects and sessions pinned to the top of their lists, each kind in the order you put them.
/// Projects are keyed by `projectDirectoryKey`, sessions by `Conversation.id`.
struct PinnedItems: Equatable {
    static let projectPathsUserDefaultsKey = "pinnedProjectPaths"
    static let conversationIDsUserDefaultsKey = "pinnedConversationIDs"

    private var pinnedProjects: PinnedOrder
    private var pinnedConversations: PinnedOrder

    init(pinnedProjectPaths: [String] = [], pinnedConversationIDs: [String] = []) {
        pinnedProjects = PinnedOrder(pinnedProjectPaths)
        pinnedConversations = PinnedOrder(pinnedConversationIDs)
    }

    /// In their pinned order.
    var pinnedProjectPaths: [String] { pinnedProjects.ids }
    /// In their pinned order, across every project.
    var pinnedConversationIDs: [String] { pinnedConversations.ids }

    static func load(from userDefaults: UserDefaults) -> PinnedItems {
        PinnedItems(
            pinnedProjectPaths: userDefaults.stringArray(forKey: projectPathsUserDefaultsKey) ?? [],
            pinnedConversationIDs: userDefaults.stringArray(forKey: conversationIDsUserDefaultsKey) ?? []
        )
    }

    /// Saved in their pinned order, which is the order they load in.
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

    /// The project's place among the pinned projects, or nil when it is not pinned.
    func pinnedPlace(ofProjectPath projectPath: String) -> Int? {
        pinnedProjects.place(of: projectPath)
    }

    /// Pinning puts the project after the other pinned projects.
    mutating func setPinned(_ isPinned: Bool, projectPath: String) {
        if isPinned { pinnedProjects.pin(projectPath) } else { pinnedProjects.unpin(projectPath) }
    }

    /// Pinning puts the session after the other pinned sessions.
    mutating func setPinned(_ isPinned: Bool, conversationID: String) {
        if isPinned { pinnedConversations.pin(conversationID) } else { pinnedConversations.unpin(conversationID) }
    }

    /// Pins the project if it is not pinned yet, at `placement` among the pinned projects.
    mutating func movePinnedProject(_ projectPath: String, to placement: PinnedPlacement) {
        pinnedProjects.move(projectPath, to: placement)
    }

    /// Pins the session if it is not pinned yet, at `placement` among the pinned sessions.
    mutating func movePinnedConversation(_ conversationID: String, to placement: PinnedPlacement) {
        pinnedConversations.move(conversationID, to: placement)
    }

    /// Moves pinned conversations to the front in their pinned order; the rest keep their incoming order.
    func pinnedConversationsFirst(_ conversations: [Conversation]) -> [Conversation] {
        let pinned = conversations
            .compactMap { conversation in pinnedConversations.place(of: conversation.id).map { (conversation, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
        return pinned + conversations.filter { !isPinned(conversationID: $0.id) }
    }
}
