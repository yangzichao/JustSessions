import Foundation

struct ProjectConversationGroup: Identifiable {
    let projectPath: String
    let displayName: String
    let isPinned: Bool
    let conversations: [Conversation]
    /// Newest first; listed above the conversations.
    let pendingNewSessions: [PendingNewSession]

    var id: String { projectPath }
    var folderName: String { ProjectDisplayNames.folderName(forProjectPath: projectPath) }
    var sessionCount: Int { conversations.count + pendingNewSessions.count }
    // Pinned sessions come first, so the newest one is not necessarily `conversations.first`.
    var latestActivity: Date {
        max(
            conversations.map(\.updatedAt).max() ?? .distantPast,
            pendingNewSessions.map(\.startedAt).max() ?? .distantPast
        )
    }

    /// The SSH host and path of a project on a remote host, or nil for a local project.
    var remoteLocation: (host: String, projectPath: String)? {
        RemoteProjectKey.location(ofKey: projectPath)
    }

    /// Always false for a remote project: its folder cannot be opened or started in from this Mac.
    var isProjectAvailable: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: projectPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func grouped(
        _ conversations: [Conversation],
        pendingNewSessions: [PendingNewSession] = [],
        displayNames: ProjectDisplayNames = ProjectDisplayNames(),
        pinnedItems: PinnedItems = PinnedItems()
    ) -> [ProjectConversationGroup] {
        let conversationsByProject = Dictionary(grouping: conversations, by: \.projectDirectoryKey)
        let pendingNewSessionsByProject = Dictionary(grouping: pendingNewSessions, by: \.projectDirectoryKey)
        return Set(conversationsByProject.keys).union(pendingNewSessionsByProject.keys)
            .map { projectPath in
                ProjectConversationGroup(
                    projectPath: projectPath,
                    displayName: displayNames.displayName(forProjectPath: projectPath),
                    isPinned: pinnedItems.isPinned(projectPath: projectPath),
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
            .sorted { first, second in
                if first.isPinned != second.isPinned { return first.isPinned }
                if first.latestActivity != second.latestActivity { return first.latestActivity > second.latestActivity }
                return first.projectPath.localizedStandardCompare(second.projectPath) == .orderedAscending
            }
    }
}
