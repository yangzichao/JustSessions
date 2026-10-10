import Foundation

enum SidebarProjectFiltering {
    /// Truly empty projects remain available for new sessions, except while only sessions waiting on you are listed.
    /// A populated project hidden by session filters must not be mistaken for an empty project.
    static func projects(
        _ projects: [ProjectConversationGroup],
        providerFilter: ConversationProviderFilter,
        recencyFilter: SessionRecencyFilter,
        waitingFilter: SessionWaitingFilter = .all,
        waiting: SessionsWaitingForYou = SessionsWaitingForYou(),
        now: Date = .now
    ) -> [ProjectConversationGroup] {
        let filteredProjects: [ProjectConversationGroup] = projects.compactMap { project in
            guard project.sessionCount > 0 else { return waitingFilter == .all ? project : nil }
            let conversations = project.conversations.filter {
                providerFilter.includes($0.provider) && recencyFilter.includes($0, now: now)
                    && waitingFilter.includes($0, waiting: waiting)
            }
            let pendingNewSessions = project.pendingNewSessions.filter {
                providerFilter.includes($0.provider) && waitingFilter.includes($0, waiting: waiting)
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

    /// A project whose name or path matches keeps all its sessions. Otherwise only sessions whose title or session
    /// ID match stay, along with those in `messageMatchConversationIDs`, and projects left with none are dropped.
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
                || project.projectPath.localizedCaseInsensitiveContains(query) {
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
