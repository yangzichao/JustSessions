import SwiftUI

struct ConversationBrowserView: View {
    @ObservedObject var store: ConversationStore
    @Binding var searchText: String
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    let onRename: (Conversation) -> Void
    let onDelete: (Conversation) -> Void
    let onDeleteConversations: ([Conversation]) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onDeleteProjectSessions: (String) -> Void

    @State private var sessionSelection = SessionMultiSelection()
    @State private var isNewSessionSheetPresented = false
    @StateObject private var updateManager = SparkleUpdateManager()

    private var providerConversations: [Conversation] {
        store.conversations.filter { providerFilter.includes($0.provider) }
    }

    private var sidebarProjects: [ProjectConversationGroup] {
        let projects = ProjectConversationGroup.grouped(
            providerConversations.filter { recencyFilter.includes($0) },
            pendingNewSessions: store.pendingNewSessions.filter { providerFilter.includes($0.provider) },
            displayNames: store.projectDisplayNames,
            pinnedItems: store.pinnedItems
        )
        return SidebarProjectFiltering.projects(projects, matching: searchText) { store.title(for: $0) }
    }

    private var availableProjects: [ProjectConversationGroup] {
        ProjectConversationGroup.grouped(
            store.conversations,
            displayNames: store.projectDisplayNames,
            pinnedItems: store.pinnedItems
        )
            .filter(\.isProjectAvailable)
    }

    private var focusedConversation: Conversation? {
        guard sessionSelection.selectedConversationIDs.count == 1,
              let conversationID = sessionSelection.selectedConversationIDs.first else { return nil }
        return store.conversations.first { $0.id == conversationID }
    }

    var body: some View {
        let providerConversations = providerConversations

        ResizableSidebarLayout {
            ConversationSidebarView(
                store: store,
                searchText: $searchText,
                recencyFilter: $recencyFilter,
                providerFilter: $providerFilter,
                sessionSelection: $sessionSelection,
                projects: sidebarProjects,
                allSessionCount: providerConversations.count,
                recentSessionCount: providerConversations.filter { SessionRecencyFilter.recent.includes($0) }.count,
                onCheckForUpdates: { updateManager.checkForUpdates() },
                onNewSession: { isNewSessionSheetPresented = true },
                onSelectConversation: { conversation in
                    sessionSelection.selectOnly(conversation.id)
                    let openTerminal = store.terminalSessions.first(where: {
                        $0.conversation?.id == conversation.id && !$0.hasExited
                    }) ?? store.terminalSessions.first(where: {
                        $0.conversation?.id == conversation.id
                    })
                    store.selectTerminal(openTerminal?.id)
                },
                onRenameConversation: onRename,
                onDeleteConversation: onDelete,
                onDeleteConversations: onDeleteConversations,
                onRenameProject: onRenameProject,
                onDeleteProjectSessions: onDeleteProjectSessions
            )
        } detail: {
            VStack(spacing: 0) {
                WorkspaceTabBar(store: store, onRenameConversation: onRename)
                ThemeDivider()
                ZStack {
                    SessionPreviewPane(
                        store: store,
                        sessionSelection: sessionSelection,
                        onRename: onRename,
                        onDelete: onDelete
                    )
                    .opacity(store.selectedTerminalID == nil ? 1 : 0)
                    .allowsHitTesting(store.selectedTerminalID == nil)
                    .accessibilityHidden(store.selectedTerminalID != nil)

                    ForEach(store.terminalSessions) { session in
                        let isActive = store.selectedTerminalID == session.id
                        TerminalWorkspaceView(
                            session: session,
                            projectDisplayName: store.projectDisplayName(forProjectPath: session.projectDirectoryKey),
                            isActive: isActive,
                            onReconnect: session.remoteHost == nil ? nil : { store.reconnectRemoteTerminal(session.id) }
                        )
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                        .accessibilityHidden(!isActive)
                    }
                }
            }
        }
        .sheet(isPresented: $isNewSessionSheetPresented) {
            NewSessionSheet(
                initialProvider: newSessionProvider,
                initialProjectPath: newSessionProjectPath,
                recentProjects: availableProjects
            ) { provider, projectPath in
                try store.launchNewSession(provider: provider, projectPath: projectPath)
            }
        }
    }

    private var newSessionProvider: ConversationProvider {
        if let selectedTerminal = store.selectedTerminal { return selectedTerminal.provider }
        switch providerFilter {
        case .claude: return .claude
        case .antigravity: return .antigravity
        case .codex, .all: return .codex
        }
    }

    /// New sessions start on this Mac, so a remote tab or session does not suggest its folder.
    private var newSessionProjectPath: String {
        if let selectedTerminal = store.selectedTerminal, selectedTerminal.remoteHost == nil {
            return selectedTerminal.projectPath
        }
        if let focusedConversation, !focusedConversation.isRemote { return focusedConversation.projectPath }
        return availableProjects.first?.projectPath ?? ""
    }
}
