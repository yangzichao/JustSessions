import SwiftUI

struct SidebarProjectSection: View {
    @ObservedObject var store: ConversationStore
    let project: ProjectConversationGroup
    let parentLabel: String?
    let isExpanded: Bool
    /// The project whose row and first session the onboarding tour points at.
    let isOnboardingTourProject: Bool
    let projectSelection: ProjectMultiSelection
    let sessionSelection: SessionMultiSelection
    let selectedConversations: [Conversation]
    let onToggleExpansion: () -> Void
    let onClickProject: () -> Void
    let onNewSession: (ConversationProvider) -> Void
    let onClickConversation: (Conversation) -> Void
    let onSelectPendingNewSession: (UUID) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onRenameProject: () -> Void
    let onRemoveSelectedProjects: () -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    /// The project row, then its sessions while it is expanded, as separate views: the sidebar's lazy list then
    /// builds only the rows in sight, even for a project with hundreds of sessions.
    var body: some View {
        SidebarProjectRow(
            store: store,
            project: project,
            parentLabel: parentLabel,
            isExpanded: isExpanded,
            projectSelection: projectSelection,
            onToggleExpansion: onToggleExpansion,
            onClick: onClickProject,
            onNewSession: onNewSession,
            onRename: onRenameProject,
            onDeleteSessions: { onRequestDeletion(.project(project.id)) },
            onRemoveProjectAndDeleteSessions: { onRequestDeletion(.projectRemoval(project.id)) },
            onRemoveSelectedProjects: onRemoveSelectedProjects
        )
        .onboardingTourStop(isOnboardingTourProject ? .projects : nil)

        if isExpanded {
            let pendingNewSessionTerminals = pendingNewSessionTerminals
            if project.sessionCount == 0 {
                Text("No sessions")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 40)
                    .padding(.vertical, 5)
                    .sidebarIndentGuide(isFirstRow: true, isLastRow: true)
            }
            ForEach(Array(pendingNewSessionTerminals.enumerated()), id: \.element.pendingNewSession.id) { index, row in
                PendingNewSessionRow(
                    terminal: row.terminal,
                    provider: row.pendingNewSession.provider,
                    isSelected: store.selectedTerminalID == row.terminal.id,
                    onSelect: { onSelectPendingNewSession(row.terminal.id) }
                )
                .sidebarIndentGuide(
                    isFirstRow: index == 0,
                    isLastRow: index == pendingNewSessionTerminals.count - 1 && project.conversations.isEmpty
                )
            }
            ForEach(project.conversations) { conversation in
                SidebarSessionRow(
                    store: store,
                    conversation: conversation,
                    sessionSelection: sessionSelection,
                    selectedConversations: selectedConversations,
                    onClick: onClickConversation,
                    onRename: onRenameConversation,
                    onRequestDeletion: onRequestDeletion
                )
                .sidebarIndentGuide(
                    isFirstRow: pendingNewSessionTerminals.isEmpty && conversation.id == project.conversations.first?.id,
                    isLastRow: conversation.id == project.conversations.last?.id
                )
                .onboardingTourStop(
                    isOnboardingTourProject && conversation.id == project.conversations.first?.id ? .sessions : nil
                )
            }
        }
    }

    /// The project's new sessions whose tab is still open, each with that tab.
    private var pendingNewSessionTerminals: [(pendingNewSession: PendingNewSession, terminal: TerminalSession)] {
        project.pendingNewSessions.compactMap { pendingNewSession in
            store.terminalSessions.first { $0.id == pendingNewSession.terminalID }.map { (pendingNewSession, $0) }
        }
    }
}
