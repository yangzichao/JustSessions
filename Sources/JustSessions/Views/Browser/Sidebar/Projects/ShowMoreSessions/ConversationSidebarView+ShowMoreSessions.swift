import SwiftUI

extension ConversationSidebarView {
    private static let mostSubagentParentStepsWalkedInCaseTheParentsLoop = 8

    struct HiddenShownSession: Equatable {
        let projectID: String
        let place: Int
    }

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

    func toggleExpansion(of projectID: String) {
        projectExpansion.toggle(projectID)
        if !projectExpansion.isExpanded(projectID, whileSearching: false) {
            sessionRowLimits.reset(projectID)
        }
    }

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

    private func topLevelConversation(of conversationID: String) -> Conversation? {
        var conversation = store.conversation(withID: conversationID)
        for _ in 0..<Self.mostSubagentParentStepsWalkedInCaseTheParentsLoop {
            guard let parentID = conversation?.parentID else { return conversation }
            conversation = store.conversation(withID: parentID)
        }
        return conversation?.isSubagent == true ? nil : conversation
    }
}

struct HiddenShownSessionReveal: ViewModifier {
    let hiddenShownSession: () -> ConversationSidebarView.HiddenShownSession?
    let reveal: (ConversationSidebarView.HiddenShownSession?) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: hiddenShownSession(), initial: true) { _, hiddenShownSession in
            reveal(hiddenShownSession)
        }
    }
}
