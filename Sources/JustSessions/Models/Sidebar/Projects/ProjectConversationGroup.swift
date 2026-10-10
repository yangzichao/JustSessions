import Foundation

struct ProjectConversationGroup: Identifiable {
    let projectPath: String
    let displayName: String
    /// The project's place among the pinned projects, which sets its order among them; nil when it is not pinned.
    let pinnedPlace: Int?
    let conversations: [Conversation]
    /// Newest first; listed below pinned sessions and above the other sessions.
    let pendingNewSessions: [PendingNewSession]
    /// Pinned sessions come first, so the newest one is not necessarily `conversations.first`. Stored, not worked
    /// out on each read: `orderedForSidebar` reads it on every comparison of a sort that runs on every render.
    let latestActivity: Date

    init(
        projectPath: String,
        displayName: String,
        pinnedPlace: Int?,
        conversations: [Conversation],
        pendingNewSessions: [PendingNewSession]
    ) {
        self.projectPath = projectPath
        self.displayName = displayName
        self.pinnedPlace = pinnedPlace
        self.conversations = conversations
        self.pendingNewSessions = pendingNewSessions
        latestActivity = max(
            conversations.map(\.updatedAt).max() ?? .distantPast,
            pendingNewSessions.map(\.startedAt).max() ?? .distantPast
        )
    }

    var id: String { projectPath }
    var isPinned: Bool { pinnedPlace != nil }
    var location: ProjectLocation { ProjectLocation(key: projectPath) }
    var host: SessionHost { location.host }
    var folderName: String { ProjectDisplayNames.folderName(forProjectPath: projectPath) }
    var sessionCount: Int { conversations.count + pendingNewSessions.count }

    var canStartNewSession: Bool { location.canStartSessions }

    static func grouped(
        _ conversations: [Conversation],
        pendingNewSessions: [PendingNewSession] = [],
        retainedProjectPaths: Set<String> = [],
        displayNames: ProjectDisplayNames = ProjectDisplayNames(),
        pinnedItems: PinnedItems = PinnedItems()
    ) -> [ProjectConversationGroup] {
        let conversationsByProject = Dictionary(grouping: conversations, by: \.projectDirectoryKey)
        let pendingNewSessionsByProject = Dictionary(grouping: pendingNewSessions, by: \.projectDirectoryKey)
        let projects = Set(conversationsByProject.keys).union(pendingNewSessionsByProject.keys)
            .union(retainedProjectPaths)
            .map { projectPath in
                ProjectConversationGroup(
                    projectPath: projectPath,
                    displayName: displayNames.displayName(forProjectPath: projectPath),
                    pinnedPlace: pinnedItems.pinnedPlace(ofProjectPath: projectPath),
                    conversations: pinnedItems.pinnedConversationsFirst(
                        (conversationsByProject[projectPath] ?? []).sorted { first, second in
                            if first.updatedAt != second.updatedAt { return first.updatedAt > second.updatedAt }
                            return first.id < second.id
                        }
                    ),
                    pendingNewSessions: (pendingNewSessionsByProject[projectPath] ?? []).sorted { first, second in
                        if first.startedAt != second.startedAt { return first.startedAt > second.startedAt }
                        return first.terminalID.uuidString < second.terminalID.uuidString
                    }
                )
            }
        return orderedForSidebar(projects)
    }

    /// Pinned projects first, in the order you put them, which activity never changes; then the rest, most recently
    /// active first.
    static func orderedForSidebar(_ projects: [ProjectConversationGroup]) -> [ProjectConversationGroup] {
        projects.sorted { first, second in
            switch (first.pinnedPlace, second.pinnedPlace) {
            case let (firstPlace?, secondPlace?): return firstPlace < secondPlace
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): break
            }
            if first.latestActivity != second.latestActivity { return first.latestActivity > second.latestActivity }
            return first.projectPath.localizedStandardCompare(second.projectPath) == .orderedAscending
        }
    }
}
