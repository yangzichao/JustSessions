import Foundation

struct ProjectConversationGroup: Identifiable {
    let projectPath: String
    let displayName: String
    let isPinned: Bool
    let conversations: [Conversation]

    var id: String { projectPath }
    var folderName: String { ProjectDisplayNames.folderName(forProjectPath: projectPath) }
    // Pinned sessions come first, so the newest one is not necessarily `conversations.first`.
    var latestActivity: Date { conversations.map(\.updatedAt).max() ?? .distantPast }

    static func grouped(
        _ conversations: [Conversation],
        displayNames: ProjectDisplayNames = ProjectDisplayNames(),
        pinnedItems: PinnedItems = PinnedItems()
    ) -> [ProjectConversationGroup] {
        Dictionary(grouping: conversations, by: \.projectDirectoryKey)
            .map { projectPath, projectConversations in
                ProjectConversationGroup(
                    projectPath: projectPath,
                    displayName: displayNames.displayName(forProjectPath: projectPath),
                    isPinned: pinnedItems.isPinned(projectPath: projectPath),
                    conversations: pinnedItems.pinnedConversationsFirst(projectConversations.sorted { first, second in
                        if first.updatedAt != second.updatedAt { return first.updatedAt > second.updatedAt }
                        return first.id < second.id
                    })
                )
            }
            .sorted { first, second in
                if first.isPinned != second.isPinned { return first.isPinned }
                if first.latestActivity != second.latestActivity { return first.latestActivity > second.latestActivity }
                return first.projectPath.localizedStandardCompare(second.projectPath) == .orderedAscending
            }
    }
}
