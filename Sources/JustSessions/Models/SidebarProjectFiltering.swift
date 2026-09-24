import Foundation

enum SidebarProjectFiltering {
    /// A project whose name or path matches keeps all its sessions. Otherwise only sessions whose
    /// title or session ID match stay, and projects left with none are dropped.
    static func projects(
        _ projects: [ProjectConversationGroup],
        matching rawQuery: String,
        title: (Conversation) -> String
    ) -> [ProjectConversationGroup] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return projects }
        return projects.compactMap { project in
            if project.displayName.localizedCaseInsensitiveContains(query)
                || project.projectPath.localizedCaseInsensitiveContains(query) {
                return project
            }
            let matchingConversations = project.conversations.filter {
                title($0).localizedCaseInsensitiveContains(query) || $0.sessionID.localizedCaseInsensitiveContains(query)
            }
            guard !matchingConversations.isEmpty else { return nil }
            return ProjectConversationGroup(
                projectPath: project.projectPath,
                displayName: project.displayName,
                isPinned: project.isPinned,
                conversations: matchingConversations
            )
        }
    }
}
