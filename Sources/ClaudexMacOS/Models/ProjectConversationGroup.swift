import Foundation

struct ProjectConversationGroup: Identifiable {
    let projectPath: String
    let conversations: [Conversation]

    var id: String { projectPath }
    var projectName: String { URL(fileURLWithPath: projectPath).lastPathComponent }
    var latestActivity: Date { conversations.first?.updatedAt ?? .distantPast }

    static func grouped(_ conversations: [Conversation]) -> [ProjectConversationGroup] {
        Dictionary(grouping: conversations, by: \.projectDirectoryKey)
            .map { projectPath, projectConversations in
                ProjectConversationGroup(
                    projectPath: projectPath,
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
