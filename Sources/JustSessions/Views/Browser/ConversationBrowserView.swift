import SwiftUI

struct ConversationBrowserView: View {
    @ObservedObject var store: ConversationStore
    @Binding var searchText: String
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    let onRename: (Conversation) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    @State private var sessionSelection = SessionMultiSelection()
    /// The host the New Session sheet opened on; nil while it is closed.
    @State private var newSessionSheetHost: SessionHost?
    @State private var closingTerminalID: UUID?
    @SceneStorage("isSidebarHidden") private var isSidebarHidden = false
    @StateObject private var updateManager = SparkleUpdateManager()

    private var filteredProjection: FilteredSidebarProjection {
        store.filteredSidebarProjection(
            providerFilter: providerFilter,
            recencyFilter: recencyFilter,
            searchText: searchText
        )
    }

    /// Projects on every host that a new session can start in, most recent first.
    private var startableProjects: [ProjectConversationGroup] {
        store.sidebarProjectGroups.filter(\.canStartNewSession)
    }

    private var focusedConversation: Conversation? {
        guard let conversationID = sessionSelection.onlySelectedConversationID else { return nil }
        return store.conversation(withID: conversationID)
    }

    var body: some View {
        let filteredProjection = filteredProjection

        ResizableSidebarLayout(isSidebarHidden: isSidebarHidden) {
            ConversationSidebarView(
                store: store,
                searchText: $searchText,
                recencyFilter: $recencyFilter,
                providerFilter: $providerFilter,
                sessionSelection: $sessionSelection,
                projects: filteredProjection.projects,
                allSessionCount: filteredProjection.allSessionCount,
                recentSessionCount: filteredProjection.recentSessionCount,
                onCheckForUpdates: { updateManager.checkForUpdates() },
                onNewSession: { newSessionSheetHost = defaultNewSessionHost },
                onNewSessionOnHost: { newSessionSheetHost = $0 },
                onSelectConversation: { conversation in
                    // A session whose CLI runs opens on its terminal. Its row stays highlighted through its tab, so,
                    // as for a new session's row, the selection clears and the highlight follows the tabs.
                    if store.showRunningCLI(for: conversation) {
                        sessionSelection.clear()
                    } else {
                        sessionSelection.selectOnly(conversation.id)
                        store.selectTerminal(nil)
                    }
                },
                onRenameConversation: onRename,
                onRenameProject: onRenameProject,
                onRequestDeletion: onRequestDeletion
            )
        } detail: {
            WorkspaceDetailView(
                store: store,
                sessionSelection: sessionSelection,
                onRename: onRename,
                onCloseTerminal: { requestClosingTerminal($0) },
                onDelete: { onRequestDeletion(.conversation($0)) }
            )
        }
        .titleBarSidebarToggle(isSidebarHidden: $isSidebarHidden)
        .focusedSceneValue(\.isSidebarHidden, $isSidebarHidden)
        .sheet(item: $newSessionSheetHost) { host in
            let startableProjects = startableProjects
            NewSessionSheet(
                initialProvider: newSessionProvider,
                initialHost: host,
                initialProjectPath: newSessionProjectPath(on: host, startableProjects: startableProjects),
                hosts: store.hosts,
                providersByHost: store.newSessionProvidersByHost,
                recentProjects: startableProjects
            ) { provider, host, folder in
                try await store.launchNewSession(provider: provider, host: host, folder: folder)
            }
        }
        .focusedSceneValue(\.workspaceTabActions, WorkspaceTabActions(
            tabCount: store.terminalSessions.count,
            hasSelectedTab: store.selectedTerminal != nil,
            isEnabled: workspaceTabCommandsEnabled,
            newSession: { newSessionSheetHost = defaultNewSessionHost },
            closeSelectedTab: { requestClosingTerminal(store.selectedTerminalID) },
            selectAdjacentTab: { store.selectAdjacentTerminal(movingForward: $0) },
            selectTab: { store.selectTerminal(shortcutNumber: $0) }
        ))
        .background(WorkspaceTabCycleShortcuts(
            isEnabled: workspaceTabCommandsEnabled && !store.terminalSessions.isEmpty,
            onSelectAdjacentTab: { store.selectAdjacentTerminal(movingForward: $0) }
        ))
        .modifier(TerminalTabCloseConfirmation(store: store, closingSessionID: $closingTerminalID))
    }

    /// A tab still waiting to be shown runs nothing, so it closes without asking what to do with its CLI.
    private func requestClosingTerminal(_ id: UUID?) {
        guard let id else { return }
        if store.terminalSessions.first(where: { $0.id == id })?.isWaitingToBeShown == true {
            store.closeTerminal(id)
        } else {
            closingTerminalID = id
        }
    }

    private var workspaceTabCommandsEnabled: Bool {
        newSessionSheetHost == nil && closingTerminalID == nil
    }

    /// The selected tab's tool, or else the one the sidebar shows; Codex when it shows every tool. The sheet takes
    /// the host's first installed tool instead when the host does not have this one.
    private var newSessionProvider: ConversationProvider {
        store.selectedTerminal?.provider ?? providerFilter.provider ?? .codex
    }

    /// The host of the selected tab, or else of the selected session, so a new session starts next to it.
    private var defaultNewSessionHost: SessionHost {
        let host = store.selectedTerminal?.host ?? focusedConversation?.host ?? .thisMac
        return store.hosts.contains(host) ? host : .thisMac
    }

    /// The selected tab's or session's folder when it is on the host, or else the host's most recent project.
    private func newSessionProjectPath(on host: SessionHost, startableProjects: [ProjectConversationGroup]) -> String {
        if let selectedTerminal = store.selectedTerminal, selectedTerminal.host == host {
            return selectedTerminal.projectPath
        }
        if let focusedConversation, focusedConversation.host == host { return focusedConversation.projectPath }
        return startableProjects.first { $0.host == host }?.location.path ?? ""
    }
}
