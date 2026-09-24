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
    let onRenameConversation: (Conversation) -> Void
    let onDeleteConversation: (Conversation) -> Void
    let onDeleteSelectedConversations: () -> Void
    let onClearSessionSelection: () -> Void
    let onRenameProject: () -> Void
    let onDeleteProjectSessions: () -> Void

    private var openTerminalCount: Int {
        store.terminalSessions.filter { $0.projectDirectoryKey == project.id }.count
    }

    private var deletionPlan: SessionDeletionPlan {
        store.deletionPlan(for: project.id)
    }

    private var isProjectAvailable: Bool {
        project.conversations.first?.isProjectAvailable == true
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                Button(action: onToggle) {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .frame(width: 15)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(project.displayName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let parentLabel {
                                Text(parentLabel)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 3)
                        if project.isPinned { PinnedIndicator() }
                        if openTerminalCount > 0 {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text("\(project.conversations.count)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .frame(height: parentLabel == nil ? 32 : 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(project.projectPath)
                .accessibilityLabel("\(project.displayName)\(project.isPinned ? ", pinned" : ""), \(project.conversations.count) \(project.conversations.count == 1 ? "session" : "sessions"), \(openTerminalCount) open")
                .contextMenu {
                    Menu("New session", systemImage: "plus") {
                        ForEach(ConversationProvider.allCases) { provider in
                            Button(provider.rawValue, systemImage: provider.symbolName) {
                                onNewSession(provider)
                            }
                        }
                    }
                    .disabled(!isProjectAvailable)
                    Button("Open project in Finder", systemImage: "folder") {
                        SessionLocationActions.openProjectFolder(project.projectPath)
                    }
                    .disabled(!isProjectAvailable)
                    Button("Copy project path", systemImage: "doc.on.doc") {
                        SessionLocationActions.copyProjectPath(project.projectPath)
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

                ProjectNewSessionMenu(project: project, showsTitle: false, onStart: onNewSession)
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .padding(.trailing, 4)
            }

            if isExpanded {
                ForEach(project.conversations) { conversation in
                    sessionRow(conversation)
                }
            }
        }
    }

    private func sessionRow(_ conversation: Conversation) -> some View {
        let openTerminal = store.terminalSessions.first {
            $0.conversation?.id == conversation.id && $0.id == store.selectedTerminalID
        } ?? store.terminalSessions.first {
            $0.conversation?.id == conversation.id
        }
        let isHighlighted = sessionSelection.contains(conversation.id)
            || (openTerminal != nil && openTerminal?.id == store.selectedTerminalID)
        let isInMultipleSelection = sessionSelection.hasMultipleSelected && sessionSelection.contains(conversation.id)
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)

        return Button {
            onClickConversation(conversation)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: conversation.provider.symbolName)
                    .font(.system(size: 11))
                    .foregroundStyle(conversation.provider.tintColor)
                    .frame(width: 14)
                Text(store.title(for: conversation))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 3)
                if isPinned { PinnedIndicator() }
                if let openTerminal {
                    TerminalStatusIndicator(session: openTerminal)
                }
            }
            .font(.system(size: 11, weight: isHighlighted ? .medium : .regular))
            .foregroundStyle(isHighlighted ? .primary : .secondary)
            .padding(.leading, 32)
            .padding(.trailing, 10)
            .frame(height: 28)
            .contentShape(Rectangle())
            .background(isHighlighted ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("\(store.title(for: conversation)) · \(conversation.provider.rawValue)")
        .accessibilityLabel("\(store.title(for: conversation)), \(conversation.provider.rawValue)\(isPinned ? ", pinned" : "")\(openTerminal == nil ? "" : ", open terminal")")
        .contextMenu {
            if isInMultipleSelection {
                SelectedSessionsContextMenu(
                    store: store,
                    selectedConversations: selectedConversations,
                    onDelete: onDeleteSelectedConversations,
                    onClear: onClearSessionSelection
                )
            } else {
                singleSessionMenu(conversation)
            }
        }
    }

    @ViewBuilder
    private func singleSessionMenu(_ conversation: Conversation) -> some View {
        Button("Resume", systemImage: "play", action: {
            store.launch(conversation, action: .resume)
        })
        .disabled(!store.canLaunch(conversation, action: .resume))
        if conversation.provider.supportsBranchFromLauncher {
            Button("Branch", systemImage: "arrow.triangle.branch", action: {
                store.launch(conversation, action: .branch)
            })
            .disabled(!store.canLaunch(conversation, action: .branch))
        }
        Divider()
        Button("Rename", systemImage: "pencil") { onRenameConversation(conversation) }
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)
        Button(isPinned ? "Unpin session" : "Pin session", systemImage: isPinned ? "pin.slash" : "pin") {
            store.setPinned(!isPinned, conversation: conversation)
        }
        Button("Copy session ID", systemImage: "doc.on.doc") {
            SessionLocationActions.copySessionID(conversation)
        }
        Button("Reveal session file in Finder", systemImage: "doc.text.magnifyingglass") {
            SessionLocationActions.revealSessionFile(conversation)
        }
        if conversation.provider.supportsDeletionFromLauncher {
            Divider()
            Button("Delete session…", systemImage: "trash", role: .destructive) {
                onDeleteConversation(conversation)
            }
            .disabled(store.hasTerminal(for: conversation) || store.isLoading || store.isDeletingSessions)
        }
    }
}
