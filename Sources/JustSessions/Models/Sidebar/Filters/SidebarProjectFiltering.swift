import Foundation

enum SidebarProjectFiltering {
    static func projects(
        _ projects: [ProjectConversationGroup],
        providerFilter: ConversationProviderFilter,
        recencyFilter: SessionRecencyFilter,
        statusFilter: SessionStatusFilter = .all,
        archiveFilter: SessionArchiveFilter = .hideArchived,
        archived: ArchivedSessions = ArchivedSessions(),
        running: SessionsRunning = SessionsRunning(),
        waiting: SessionsWaitingForYou = SessionsWaitingForYou(),
        now: Date = .now
    ) -> [ProjectConversationGroup] {
        let filteredProjects: [ProjectConversationGroup] = projects.compactMap { project in
            let unarchivedConversations = project.conversations.filter { archiveFilter.includes($0, archived: archived) }
            guard !unarchivedConversations.isEmpty || !project.pendingNewSessions.isEmpty else {
                guard statusFilter == .all else { return nil }
                return unarchivedConversations.count == project.conversations.count
                    ? project
                    : ProjectConversationGroup(
                        projectPath: project.projectPath,
                        displayName: project.displayName,
                        pinnedPlace: project.pinnedPlace,
                        conversations: [],
                        pendingNewSessions: []
                    )
            }
            let conversations = unarchivedConversations.filter {
                providerFilter.includes($0.provider) && recencyFilter.includes($0, now: now)
                    && statusFilter.includes($0, running: running, waiting: waiting)
            }
            let pendingNewSessions = project.pendingNewSessions.filter {
                providerFilter.includes($0.provider) && statusFilter.includes($0, running: running, waiting: waiting)
            }
            guard !conversations.isEmpty || !pendingNewSessions.isEmpty else { return nil }
            return ProjectConversationGroup(
                projectPath: project.projectPath,
                displayName: project.displayName,
                pinnedPlace: project.pinnedPlace,
                conversations: conversations,
                pendingNewSessions: pendingNewSessions
            )
        }
        return ProjectConversationGroup.orderedForSidebar(filteredProjects)
    }

    static func projects(
        _ projects: [ProjectConversationGroup],
        matching rawQuery: String,
        title: (Conversation) -> String,
        messageMatchConversationIDs: Set<String> = []
    ) -> [ProjectConversationGroup] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return projects }
        return projects.compactMap { project in
            if project.displayName.localizedCaseInsensitiveContains(query)
                || project.projectPath.localizedCaseInsensitiveContains(query)
            {
                return project
            }
            let matchingConversations = project.conversations.filter {
                title($0).localizedCaseInsensitiveContains(query) || $0.sessionID.localizedCaseInsensitiveContains(query)
                    || messageMatchConversationIDs.contains($0.id)
            }
            let matchingPendingNewSessions = project.pendingNewSessions.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
            guard !matchingConversations.isEmpty || !matchingPendingNewSessions.isEmpty else { return nil }
            return ProjectConversationGroup(
                projectPath: project.projectPath,
                displayName: project.displayName,
                pinnedPlace: project.pinnedPlace,
                conversations: matchingConversations,
                pendingNewSessions: matchingPendingNewSessions
            )
        }
    }
}
