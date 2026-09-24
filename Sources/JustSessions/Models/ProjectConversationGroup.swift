import Foundation

struct ProjectConversationGroup: Identifiable {
    let projectPath: String
    let displayName: String
    let conversations: [Conversation]

    var id: String { projectPath }
    var folderName: String { ProjectDisplayNames.folderName(forProjectPath: projectPath) }
    var latestActivity: Date { conversations.first?.updatedAt ?? .distantPast }

    static func grouped(
        _ conversations: [Conversation],
        displayNames: ProjectDisplayNames = ProjectDisplayNames()
    ) -> [ProjectConversationGroup] {
        Dictionary(grouping: conversations, by: \.projectDirectoryKey)
            .map { projectPath, projectConversations in
                ProjectConversationGroup(
                    projectPath: projectPath,
                    displayName: displayNames.displayName(forProjectPath: projectPath),
                    conversations: projectConversations.sorted { first, second in
                        if first.updatedAt != second.updatedAt { return first.updatedAt > second.updatedAt }
                        return first.id < second.id
                    }
                )
            }
            .sorted { first, second in
                if first.latestActivity != second.latestActivity { return first.latestActivity > second.latestActivity }
                return first.projectPath.localizedStandardCompare(second.projectPath) == .orderedAscending
            }
    }
}
