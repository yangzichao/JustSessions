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
    /// The host the New Session sheet opened on; nil while it is closed.
    @State private var newSessionSheetHost: SessionHost?
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

    /// Projects on every host that a new session can start in, most recent first.
    private var startableProjects: [ProjectConversationGroup] {
        ProjectConversationGroup.grouped(
            store.conversations,
            displayNames: store.projectDisplayNames,
            pinnedItems: store.pinnedItems
        )
            .filter(\.canStartNewSession)
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
                onNewSession: { newSessionSheetHost = defaultNewSessionHost },
                onNewSessionOnHost: { newSessionSheetHost = $0 },
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
                            hostDisplayName: store.hasRemoteHosts ? session.host.displayName : nil,
                            isActive: isActive,
                            onReconnect: session.host == .thisMac ? nil : { store.reconnectRemoteTerminal(session.id) }
                        )
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                        .accessibilityHidden(!isActive)
                    }
                }
            }
        }
        .sheet(item: $newSessionSheetHost) { host in
            NewSessionSheet(
                initialProvider: newSessionProvider,
                initialHost: host,
                initialProjectPath: newSessionProjectPath(on: host),
                hosts: store.hosts,
                recentProjects: startableProjects
            ) { provider, host, folder in
                try await store.launchNewSession(provider: provider, host: host, folder: folder)
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

    /// The host of the selected tab, or else of the selected session, so a new session starts next to it.
    private var defaultNewSessionHost: SessionHost {
        let host = store.selectedTerminal?.host ?? focusedConversation?.host ?? .thisMac
        return store.hosts.contains(host) ? host : .thisMac
    }

    /// The selected tab's or session's folder when it is on the host, or else the host's most recent project.
    private func newSessionProjectPath(on host: SessionHost) -> String {
        if let selectedTerminal = store.selectedTerminal, selectedTerminal.host == host {
            return selectedTerminal.projectPath
        }
        if let focusedConversation, focusedConversation.host == host { return focusedConversation.projectPath }
        return startableProjects.first { $0.host == host }?.location.path ?? ""
    }
}
