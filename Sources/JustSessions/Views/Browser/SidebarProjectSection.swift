import SwiftUI

struct SidebarProjectSection: View {
    @ObservedObject var store: ConversationStore
    let project: ProjectConversationGroup
    let parentLabel: String?
    let isExpanded: Bool
    let sessionSelection: SessionMultiSelection
    let selectedConversations: [Conversation]
    let onToggle: () -> Void
    let onNewSession: (ConversationProvider) -> Void
    let onClickConversation: (Conversation) -> Void
    let onSelectPendingNewSession: (UUID) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onDeleteConversation: (Conversation) -> Void
    let onDeleteSelectedConversations: () -> Void
    let onClearSessionSelection: () -> Void
    let onRenameProject: () -> Void
    let onDeleteProjectSessions: () -> Void

    @State private var isHovered = false

    private var openTerminalCount: Int {
        store.terminalSessions.filter { $0.projectDirectoryKey == project.id }.count
    }

    /// The host of a remote project, then the parent folder when another project has the same name.
    private var secondaryLabel: String? {
        let labels = [project.remoteLocation?.host, parentLabel].compactMap { $0 }
        return labels.isEmpty ? nil : labels.joined(separator: " · ")
    }

    private var deletionPlan: SessionDeletionPlan {
        store.deletionPlan(for: project.id)
    }

    var body: some View {
        VStack(spacing: 1) {
            projectRow

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(project.pendingNewSessions) { pendingNewSession in
                        if let terminal = store.terminalSessions.first(where: { $0.id == pendingNewSession.terminalID }) {
                            PendingNewSessionRow(
                                terminal: terminal,
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
                            onDelete: onDeleteConversation,
                            onDeleteSelected: onDeleteSelectedConversations,
                            onClearSelection: onClearSessionSelection
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
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1)
            .padding(.leading, 15)
            .padding(.vertical, 3)
    }

    private var projectRow: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeOut(duration: 0.12), value: isExpanded)
                        .frame(width: 10)
                    Image(systemName: project.remoteLocation == nil ? "folder" : "network")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(project.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let secondaryLabel {
                            Text(secondaryLabel)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if project.isPinned { PinnedIndicator() }
                    if openTerminalCount > 0 {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(Color.green)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .frame(height: secondaryLabel == nil ? 30 : 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .help(RemoteProjectKey.copyablePath(ofKey: project.projectPath))
            .accessibilityLabel("\(project.displayName)\(project.isPinned ? ", pinned" : ""), \(project.sessionCount) \(project.sessionCount == 1 ? "session" : "sessions"), \(openTerminalCount) open")
            .contextMenu {
                Menu("New session", systemImage: "plus") {
                    ForEach(project.newSessionProviders) { provider in
                        Button(provider.rawValue, systemImage: provider.symbolName) {
                            onNewSession(provider)
                        }
                    }
                }
                .disabled(!project.canStartNewSession)
                Button("Open project in Finder", systemImage: "folder") {
                    SessionLocationActions.openProjectFolder(project.projectPath)
                }
                .disabled(!project.isProjectAvailable)
                Button("Copy project path", systemImage: "doc.on.doc") {
                    SessionLocationActions.copyProjectPath(RemoteProjectKey.copyablePath(ofKey: project.projectPath))
                }
                Button("Rename project…", systemImage: "pencil", action: onRenameProject)
                Button(project.isPinned ? "Unpin project" : "Pin project", systemImage: project.isPinned ? "pin.slash" : "pin") {
                    store.setPinned(!project.isPinned, projectPath: project.projectPath)
                }
                Divider()
                Button("Delete all deletable sessions (\(deletionPlan.deletableConversations.count))…", systemImage: "trash", role: .destructive) {
                    onDeleteProjectSessions()
                }
                .disabled(!deletionPlan.hasDeletableConversations || store.isLoading || store.isDeletingSessions)
            }

            sessionCountOrNewSessionMenu
                .padding(.trailing, 8)
        }
        .background(SidebarRowBackground(isSelected: false, isHovered: isHovered))
        .onHover { isHovered = $0 }
    }

    /// The session count, which gives way to the + menu while the pointer is over the row.
    private var sessionCountOrNewSessionMenu: some View {
        ZStack(alignment: .trailing) {
            Text(project.sessionCount.formatted())
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .opacity(isHovered ? 0 : 1)
            ProjectNewSessionMenu(project: project, showsTitle: false, onStart: onNewSession)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
        }
    }
}
