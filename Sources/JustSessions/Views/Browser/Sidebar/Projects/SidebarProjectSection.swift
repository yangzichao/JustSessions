import SwiftUI

struct SidebarProjectSection: View {
    @ObservedObject var store: ConversationStore
    let project: ProjectConversationGroup
    let parentLabel: String?
    let isExpanded: Bool
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

    var body: some View {
        VStack(spacing: 1) {
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
                onRemoveSelectedProjects: onRemoveSelectedProjects
            )

            if isExpanded {
                VStack(spacing: 1) {
                    if project.sessionCount == 0 {
                        Text("No sessions")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 40)
                            .padding(.vertical, 5)
                    }
                    ForEach(project.pendingNewSessions) { pendingNewSession in
                        if let terminal = store.terminalSessions.first(where: { $0.id == pendingNewSession.terminalID }) {
                            PendingNewSessionRow(
                                terminal: terminal,
                                provider: pendingNewSession.provider,
                                isSelected: store.selectedTerminalID == terminal.id,
                                onSelect: { onSelectPendingNewSession(terminal.id) }
                            )
                        }
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
                    }
                }
                .background(alignment: .leading) { indentGuide }
            }
        }
    }

    /// A hairline under the chevron that ties the sessions to their project.
    private var indentGuide: some View {
        Rectangle()
            .fill(ThemePalette.hairline)
            .frame(width: 1)
            .padding(.leading, 15)
            .padding(.vertical, 3)
    }
}
