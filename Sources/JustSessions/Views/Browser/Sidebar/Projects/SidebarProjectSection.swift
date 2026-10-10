import SwiftUI

struct SidebarProjectSection: View {
    @ObservedObject var store: ConversationStore
    let project: ProjectConversationGroup
    let parentLabel: String?
    let pinDragging: SidebarPinDragging
    /// The host's projects as listed, for a drag of this one among them.
    let hostProjectRows: () -> [SidebarPinDrag.Row]
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

    private var projectScope: SidebarPinDrag.Scope { .projects(on: project.host) }
    private var sessionScope: SidebarPinDrag.Scope { .sessions(inProject: project.id) }
    private var projectRowID: String { SidebarPinDrag.Row.projectRowID(project.projectPath) }

    private var landingLineLeadingInset: CGFloat {
        pinDragging.drag?.scope.landingLineLeadingInset ?? 0
    }

    /// The project row, then its sessions while it is expanded, as separate views: the sidebar's lazy list then
    /// builds only the rows in sight, even for a project with hundreds of sessions. Pinned sessions come first, then
    /// new sessions, then the rest.
    var body: some View {
        let pendingNewSessionTerminals = isExpanded ? self.pendingNewSessionTerminals : [:]
        let rows = isExpanded
            ? ProjectSessionRow.ordered(
                conversations: project.conversations,
                pendingNewSessions: project.pendingNewSessions.filter { pendingNewSessionTerminals[$0.id] != nil },
                pinnedItems: store.pinnedItems
            )
            : []

        projectRow

        if isExpanded {
            if project.sessionCount == 0 {
                Text("No sessions")
                    .font(.system(size: 11))
                    .foregroundStyle(ThemePalette.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 40)
                    .padding(.vertical, 5)
                    .sidebarIndentGuide(isFirstRow: true, isLastRow: true)
                    .reportsSidebarRowFrame("empty:\(project.id)", inProject: project.id, to: pinDragging.rowFrames)
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
                        .reportsSidebarRowFrame(row.id, inProject: project.id, to: pinDragging.rowFrames)
                    }
                case .conversation(let conversation):
                    conversationRows(conversation, rowID: row.id, among: rows, isFirstRow: isFirstRow, isLastRow: isLastRow)
                }
            }
        }
    }

    /// The project's own row, which drags among its host's projects.
    private var projectRow: some View {
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
        .reportsSidebarRowFrame(projectRowID, inProject: project.id, to: pinDragging.rowFrames)
        .sidebarPinDragSource(
            isDragged: pinDragging.isDragging(projectRowID),
            translation: pinDragging.drag?.translation ?? 0,
            landingLineOffset: pinDragging.landingLineOffset(fromTopOf: projectRowID),
            landingLineLeadingInset: landingLineLeadingInset,
            onChanged: { pinDragging.onDrag(projectRowID, projectScope, hostProjectRows, $0) },
            onEnded: pinDragging.onDrop,
            onCancelled: pinDragging.onCancel
        ) {
            HStack(spacing: 0) {
                Color.clear.frame(width: SidebarProjectRow.chevronWidth)
                SidebarProjectLabel(project: project, parentLabel: parentLabel)
                Spacer(minLength: 0)
            }
            .frame(height: SidebarProjectRow.height(withParentLabel: parentLabel != nil))
        }
    }

    /// A session's row, which drags among the project's sessions, then its subagents' rows while they show.
    @ViewBuilder
    private func conversationRows(
        _ conversation: Conversation,
        rowID: String,
        among rows: [ProjectSessionRow],
        isFirstRow: Bool,
        isLastRow: Bool
    ) -> some View {
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
        .reportsSidebarRowFrame(rowID, inProject: project.id, to: pinDragging.rowFrames)
        .sidebarPinDragSource(
            isDragged: pinDragging.isDragging(rowID),
            translation: pinDragging.drag?.translation ?? 0,
            landingLineOffset: pinDragging.landingLineOffset(fromTopOf: rowID),
            landingLineLeadingInset: landingLineLeadingInset,
            onChanged: { pinDragging.onDrag(rowID, sessionScope, { sessionRows(rows) }, $0) },
            onEnded: pinDragging.onDrop,
            onCancelled: pinDragging.onCancel
        ) {
            SidebarSessionRowLayout(provider: conversation.provider, isSelected: false) {
                HStack(spacing: 4) {
                    Text(store.title(for: conversation))
                    if store.pinnedItems.isPinned(conversationID: conversation.id) { PinnedIndicator() }
                }
            } trailing: {
                EmptyView()
            }
        }

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
            .reportsSidebarRowFrame("subagent:\(row.id)", inProject: project.id, to: pinDragging.rowFrames)
        }
    }

    private func sessionRows(_ rows: [ProjectSessionRow]) -> [SidebarPinDrag.Row] {
        rows.map { SidebarPinDrag.Row.session($0, pinnedItems: store.pinnedItems) }
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
