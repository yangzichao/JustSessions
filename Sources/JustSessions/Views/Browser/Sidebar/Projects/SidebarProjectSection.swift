import SwiftUI

struct SidebarProjectSection: View {
    let store: ConversationStore
    let project: ProjectConversationGroup
    let parentLabel: String?
    let pinDragging: SidebarPinDragging
    let hostProjectRows: () -> [SidebarPinDrag.Row]
    let isExpanded: Bool
    let sessionLimit: Int?
    let isOnboardingTourProject: Bool
    let projectSelection: ProjectMultiSelection
    let sessionSelection: SessionMultiSelection
    let selectedConversations: [Conversation]
    let showsSubagents: Bool
    let subagentRows: SidebarSubagentRows
    let onToggleSubagents: (Conversation) -> Void
    let messageMatches: [String: SessionMessageMatch]
    var bookmarkMatches: [String: [MessageBookmark]] = [:]
    let onToggleExpansion: () -> Void
    let onShowMoreSessions: (Int) -> Void
    let onClickProject: () -> Void
    let onNewSession: (ConversationProvider) -> Void
    let onClickConversation: (Conversation) -> Void
    let onSelectPendingNewSession: (UUID) -> Void
    let onDroppedRowIntoTerminals: () -> Void
    let onRenameConversation: (Conversation) -> Void
    let onRenameProject: () -> Void
    let onRemoveSelectedProjects: () -> Void
    let onRemoveSelectedProjectsAndDeleteSessions: () -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    private var projectScope: SidebarPinDrag.Scope { .projects(on: project.host) }
    private var sessionScope: SidebarPinDrag.Scope { .sessions(inProject: project.id) }
    private var projectRowID: SidebarRowID { .project(path: project.projectPath) }

    private var landingLineLeadingInset: CGFloat {
        pinDragging.drag?.scope.landingLineLeadingInset ?? 0
    }

    var body: some View {
        let pendingNewSessionTerminals = isExpanded ? self.pendingNewSessionTerminals : [:]
        let listedRows =
            isExpanded
            ? ListedProjectSessionRows(
                conversations: project.conversations,
                pendingNewSessions: project.pendingNewSessions.filter { pendingNewSessionTerminals[$0.id] != nil },
                pinnedItems: store.pinnedItems,
                sessionLimit: sessionLimit
            )
            : nil
        let rows = listedRows?.rows ?? []
        let hiddenSessionCount = listedRows?.hiddenSessionCount ?? 0

        projectRow

        if isExpanded {
            if project.sessionCount == 0 {
                Text("No sessions")
                    .font(ThemeFont.detail)
                    .foregroundStyle(ThemePalette.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 40)
                    .padding(.vertical, 5)
                    .sidebarIndentGuide(isFirstRow: true, isLastRow: true)
                    .reportsSidebarRowFrame(.emptyProject(path: project.id), inProject: project.id, to: pinDragging.rowFrames)
            }
            ForEach(rows) { row in
                let isFirstRow = row.id == rows.first?.id
                let isLastRow = hiddenSessionCount == 0 && row.id == rows.last?.id
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
                        .sidebarRowDragIntoSplit(
                            .openTab(terminal.id),
                            titled: terminal.displayTitle,
                            in: store,
                            fadesWhileDragged: true,
                            onDropped: onDroppedRowIntoTerminals
                        )
                    }
                case .conversation(let conversation):
                    conversationRows(conversation, rowID: row.id, among: rows, isFirstRow: isFirstRow, isLastRow: isLastRow)
                }
            }
            if hiddenSessionCount > 0 {
                SidebarShowMoreSessionsRow(
                    sessionCount: ProjectSessionRowLimits.sessionsShownByShowMore(hiddenSessionCount: hiddenSessionCount),
                    onShowMore: { onShowMoreSessions(hiddenSessionCount) }
                )
                .sidebarIndentGuide(isFirstRow: rows.isEmpty, isLastRow: true)
            }
        }
    }

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
            ghostOffset: pinDragging.ghostOffset(of: projectRowID),
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

    @ViewBuilder
    private func conversationRows(
        _ conversation: Conversation,
        rowID: SidebarRowID,
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
            bookmarkMatches: bookmarkMatches[conversation.id] ?? [],
            onClick: onClickConversation,
            onToggleSubagents: { onToggleSubagents(conversation) },
            onRename: onRenameConversation,
            onRequestDeletion: onRequestDeletion
        )
        .sidebarIndentGuide(isFirstRow: isFirstRow, isLastRow: isLastRow && rowsUnder.isEmpty)
        .onboardingTourStop(
            isOnboardingTourProject && conversation.id == project.conversations.first?.id ? .sessions : nil
        )
        .onboardingTourStop(sessionSelection.onlySelectedConversationID == conversation.id ? .sessionMenu : nil)
        .reportsSidebarRowFrame(rowID, inProject: project.id, to: pinDragging.rowFrames)
        .sidebarPinDragSource(
            isDragged: pinDragging.isDragging(rowID),
            ghostOffset: pinDragging.ghostOffset(of: rowID),
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
        .sidebarRowDragIntoSplit(
            .session(conversation),
            titled: store.title(for: conversation),
            in: store,
            onDropped: onDroppedRowIntoTerminals
        )

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
            .reportsSidebarRowFrame(.subagent(conversationID: row.id), inProject: project.id, to: pinDragging.rowFrames)
        }
    }

    private func sessionRows(_ rows: [ProjectSessionRow]) -> [SidebarPinDrag.Row] {
        rows.map { SidebarPinDrag.Row.session($0, pinnedItems: store.pinnedItems) }
    }

    private func listedSubagents(of conversation: Conversation) -> [Conversation] {
        showsSubagents ? store.subagents(of: conversation) : []
    }

    private var pendingNewSessionTerminals: [UUID: TerminalSession] {
        var terminals: [UUID: TerminalSession] = [:]
        for pendingNewSession in project.pendingNewSessions {
            terminals[pendingNewSession.id] = store.terminalSessions.first { $0.id == pendingNewSession.terminalID }
        }
        return terminals
    }
}
