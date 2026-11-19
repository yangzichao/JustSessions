import SwiftUI

/// A project lists its first sessions, then "Show N more"; see `ProjectSessionRowLimits`.
extension ConversationSidebarView {
    /// A session the window shows whose row is hidden below "Show N more".
    struct HiddenShownSession: Equatable {
        let projectID: String
        /// Its place among the sessions the limit counts.
        let place: Int
    }

    /// The limit on the project's session rows. A search or a status filter lists every session it finds, since that is
    /// exactly what you asked to see.
    func sessionLimit(for project: ProjectConversationGroup) -> Int? {
        guard !isSearching, statusFilter == .all else { return nil }
        return sessionRowLimits.sessionLimit(inProject: project.id)
    }

    func listedSessionRows(of project: ProjectConversationGroup) -> ListedProjectSessionRows {
        ListedProjectSessionRows(
            conversations: project.conversations,
            pendingNewSessions: project.pendingNewSessions,
            pinnedItems: store.pinnedItems,
            sessionLimit: sessionLimit(for: project)
        )
    }

    /// Collapsing a project puts it back to its first sessions.
    func toggleExpansion(of projectID: String) {
        projectExpansion.toggle(projectID)
        if !projectExpansion.isExpanded(projectID, whileSearching: false) {
            sessionRowLimits.reset(projectID)
        }
    }

    /// The session the window shows, by a click, Back, a notification, or its selected tab, when its row is hidden in
    /// an expanded project. For a subagent's session, the session listed under the project it hangs off.
    var hiddenShownSession: HiddenShownSession? {
        guard
            let shownConversationID = sessionSelection.onlySelectedConversationID
                ?? store.selectedTerminal?.conversation?.id,
            let conversation = topLevelConversation(of: shownConversationID),
            let project = projects.first(where: { $0.id == conversation.projectDirectoryKey }),
            isExpanded(project),
            let place = ListedProjectSessionRows.hiddenPlace(
                of: conversation.id,
                in: project.conversations,
                pinnedItems: store.pinnedItems,
                sessionLimit: sessionLimit(for: project)
            )
        else { return nil }
        return HiddenShownSession(projectID: project.id, place: place)
    }

    func reveal(_ hiddenShownSession: HiddenShownSession?) {
        guard let hiddenShownSession else { return }
        sessionRowLimits.reveal(sessionAt: hiddenShownSession.place, inProject: hiddenShownSession.projectID)
    }

    /// Subagents' sessions can nest; the walk stops after a few steps should their parents ever loop.
    private func topLevelConversation(of conversationID: String) -> Conversation? {
        var conversation = store.conversation(withID: conversationID)
        for _ in 0..<8 {
            guard let parentID = conversation?.parentID else { return conversation }
            conversation = store.conversation(withID: parentID)
        }
        return conversation?.isSubagent == true ? nil : conversation
    }
}

/// Lists the shown session's row when it is hidden below "Show N more". The session the window shows changes with every
/// tab switch, so it is worked out in this modifier's body: a switch then redraws only this, rather than the sidebar
/// and every project in it.
struct HiddenShownSessionReveal: ViewModifier {
    let hiddenShownSession: () -> ConversationSidebarView.HiddenShownSession?
    let reveal: (ConversationSidebarView.HiddenShownSession?) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: hiddenShownSession(), initial: true) { _, hiddenShownSession in
            reveal(hiddenShownSession)
        }
    }
}
