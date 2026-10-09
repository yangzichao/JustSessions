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
    /// Whether sessions offer a chevron that lists their subagents' sessions; without it, none are listed.
    let showsSubagents: Bool
    /// Which sessions show their subagents' sessions under them.
    let subagentRows: SidebarSubagentRows
    let onToggleSubagents: (Conversation) -> Void
    let messageMatches: [String: SessionMessageMatch]
    let onToggleExpansion: () -> Void
    let onClickProject: () -> Void
    let onNewSession: (ConversationProvider) -> Void
    let onClickConversation: (Conversation) -> Void
    let onSelectPendingNewSession: (UUID) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onRenameProject: () -> Void
    let onRemoveSelectedProjects: () -> Void
    let onRemoveSelectedProjectsAndDeleteSessions: () -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void
    let onCloseTab: (UUID) -> Void

    /// The project row, then its sessions while it is expanded, as separate views: the sidebar's lazy list then
    /// builds only the rows in sight, even for a project with hundreds of sessions. Pinned sessions come first, then
    /// new sessions, then the rest.
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
            onRemoveSelectedProjects: onRemoveSelectedProjects,
            onRemoveSelectedProjectsAndDeleteSessions: onRemoveSelectedProjectsAndDeleteSessions
        )
        .onboardingTourStop(isOnboardingTourProject ? .projects : nil)

        if isExpanded {
            let pendingNewSessionTerminals = pendingNewSessionTerminals
            let rows = ProjectSessionRow.ordered(
                conversations: project.conversations,
                pendingNewSessions: project.pendingNewSessions.filter { pendingNewSessionTerminals[$0.id] != nil },
                pinnedItems: store.pinnedItems
            )
            if project.sessionCount == 0 {
                Text("No sessions")
                    .font(.system(size: 11))
                    .foregroundStyle(ThemePalette.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 40)
                    .padding(.vertical, 5)
                    .sidebarIndentGuide(isFirstRow: true, isLastRow: true)
            }
            ForEach(rows) { row in
                let isFirstRow = row.id == rows.first?.id
                let isLastRow = row.id == rows.last?.id
                switch row {
                case .pendingNewSession(let pendingNewSession):
                    if let terminal = pendingNewSessionTerminals[pendingNewSession.id] {
                        PendingNewSessionRow(
                            terminal: terminal,
                            provider: pendingNewSession.provider,
                            isSelected: store.selectedTerminalID == terminal.id,
                            onSelect: { onSelectPendingNewSession(terminal.id) }
                        )
                        .sidebarIndentGuide(isFirstRow: isFirstRow, isLastRow: isLastRow)
                    }
                case .conversation(let conversation):
                    conversationRows(conversation, isFirstRow: isFirstRow, isLastRow: isLastRow)
                }
            }
        }
    }

    /// A session's row, then its subagents' rows while they show.
    @ViewBuilder
    private func conversationRows(_ conversation: Conversation, isFirstRow: Bool, isLastRow: Bool) -> some View {
        let rowsUnder = subagentRows.rows(under: conversation, subagents: listedSubagents(of:))
        SidebarSessionRow(
            store: store,
            conversation: conversation,
            sessionSelection: sessionSelection,
            selectedConversations: selectedConversations,
            subagentCount: listedSubagents(of: conversation).count,
            isShowingSubagents: subagentRows.isExpanded(conversation.id),
            messageMatch: messageMatches[conversation.id],
            onClick: onClickConversation,
            onToggleSubagents: { onToggleSubagents(conversation) },
            onRename: onRenameConversation,
            onRequestDeletion: onRequestDeletion,
            onCloseTab: onCloseTab
        )
        .sidebarIndentGuide(isFirstRow: isFirstRow, isLastRow: isLastRow && rowsUnder.isEmpty)
        .onboardingTourStop(
            isOnboardingTourProject && conversation.id == project.conversations.first?.id ? .sessions : nil
        )
        .onboardingTourStop(sessionSelection.onlySelectedConversationID == conversation.id ? .sessionMenu : nil)

        ForEach(rowsUnder) { row in
            SidebarSubagentRow(
                store: store,
                row: row,
                isSelected: sessionSelection.contains(row.id),
                isExpanded: subagentRows.isExpanded(row.id),
                onClick: onClickConversation,
                onToggleSubagents: { onToggleSubagents(row.conversation) }
            )
            .sidebarIndentGuide(isFirstRow: false, isLastRow: isLastRow && row.id == rowsUnder.last?.id)
        }
    }

    private func listedSubagents(of conversation: Conversation) -> [Conversation] {
        showsSubagents ? store.subagents(of: conversation) : []
    }

    /// The tabs of the project's new sessions whose tab is still open, by the new session's id.
    private var pendingNewSessionTerminals: [UUID: TerminalSession] {
        var terminals: [UUID: TerminalSession] = [:]
        for pendingNewSession in project.pendingNewSessions {
            terminals[pendingNewSession.id] = store.terminalSessions.first { $0.id == pendingNewSession.terminalID }
        }
        return terminals
    }
}
