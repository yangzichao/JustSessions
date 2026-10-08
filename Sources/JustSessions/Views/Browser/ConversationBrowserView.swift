import SwiftUI

struct ConversationBrowserView: View {
    @ObservedObject var store: ConversationStore
    @Binding var searchText: String
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    @Binding var waitingFilter: SessionWaitingFilter
    let onRename: (Conversation) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    @State private var sessionSelection = SessionMultiSelection()
    @State private var messageSearch = SidebarMessageSearch()
    /// The match a click on a session row found in messages opens the reader at.
    @State private var transcriptMatchReveal: TranscriptMatchReveal?
    /// The host the New Session sheet opened on; nil while it is closed.
    @State private var newSessionSheetHost: SessionHost?
    /// Settings or Help while either shows as a sheet on this window.
    @State private var appWideSheet: AppWideSheet?
    @State private var closingTerminalID: UUID?
    @SceneStorage("isSidebarHidden") private var isSidebarHidden = false
    @StateObject private var updateManager = SparkleUpdateManager()
    @StateObject private var onboardingTour = OnboardingTour()

    private var filteredProjection: FilteredSidebarProjection {
        store.filteredSidebarProjection(
            providerFilter: providerFilter,
            recencyFilter: recencyFilter,
            waitingFilter: waitingFilter,
            searchText: searchText,
            messageMatchConversationIDs: Set(messageSearch.results.matchesByConversationID.keys)
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
                waitingFilter: $waitingFilter,
                sessionSelection: $sessionSelection,
                projects: filteredProjection.projects,
                allSessionCount: filteredProjection.allSessionCount,
                recentSessionCount: filteredProjection.recentSessionCount,
                waitingSessionCount: filteredProjection.waitingSessionCount,
                messageMatches: searchText.isEmpty ? [:] : messageSearch.results.matchesByConversationID,
                onNewSession: { newSessionSheetHost = defaultNewSessionHost },
                onSelectConversation: { conversation in
                    // A session a search found in messages opens its reader at the match, even while its CLI runs.
                    if !searchText.isEmpty, let match = messageSearch.match(for: conversation.id) {
                        sessionSelection.selectOnly(conversation.id)
                        store.selectTerminal(nil)
                        transcriptMatchReveal = TranscriptMatchReveal(
                            conversationID: conversation.id, entryID: match.entryID, query: messageSearch.results.query
                        )
                    // A session whose CLI runs opens on its terminal. Its row stays highlighted through its tab, so,
                    // as for a new session's row, the selection clears and the highlight follows the tabs.
                    } else if store.showRunningCLI(for: conversation) {
                        sessionSelection.clear()
                    } else {
                        sessionSelection.selectOnly(conversation.id)
                        store.selectTerminal(nil)
                    }
                },
                onRenameConversation: onRename,
                onRenameProject: onRenameProject,
                onRequestDeletion: onRequestDeletion,
                onCloseTerminal: { requestClosingTerminal($0) }
            )
        } detail: {
            WorkspaceDetailView(
                store: store,
                sessionSelection: sessionSelection,
                transcriptMatchReveal: transcriptMatchReveal,
                isSidebarHidden: isSidebarHidden,
                onRename: onRename,
                onCloseTerminal: { requestClosingTerminal($0) },
                onDelete: { onRequestDeletion(.conversation($0)) }
            )
        }
        .background(SidebarMessageSearchDriver(
            indexer: store.messageIndexer,
            search: messageSearch,
            typedQuery: searchText,
            conversations: store.sidebarConversations,
            conversationsRevision: store.conversationsRevision
        ))
        // A reveal opens the reader only for the session it was made for, and only once.
        .onChange(of: sessionSelection.onlySelectedConversationID) { _, conversationID in
            if conversationID != transcriptMatchReveal?.conversationID { transcriptMatchReveal = nil }
        }
        .titleBarSidebarToggle(isSidebarHidden: $isSidebarHidden)
        .focusedSceneValue(\.isSidebarHidden, $isSidebarHidden)
        .sheet(item: $newSessionSheetHost) { host in
            let startableProjects = startableProjects
            NewSessionSheet(
                initialKind: newSessionKind,
                initialHost: host,
                initialProjectPath: newSessionProjectPath(on: host, startableProjects: startableProjects),
                hosts: store.hosts,
                providersByHost: store.newSessionProvidersByHost,
                recentProjects: startableProjects,
                startCommands: store.cliStartCommands,
                onSaveStartCommand: { try await store.saveStartCommand($0, for: $1, on: $2) }
            ) { request in
                switch request.kind {
                case .cli(let provider):
                    try await store.launchNewSession(provider: provider, host: request.host, folder: request.folder)
                case .plainTerminal:
                    try await store.openPlainTerminal(host: request.host, folder: request.folder)
                }
            }
        }
        .dismissesOnClickOutside(item: $newSessionSheetHost)
        .showsAppWideSheets($appWideSheet, onCheckForUpdates: { updateManager.checkForUpdates() })
        .focusedSceneValue(\.workspaceTabActions, WorkspaceTabActions(
            tabCount: store.terminalSessions.count,
            hasSelectedTab: store.selectedTerminal != nil,
            isSplitShown: store.shownSplit != nil,
            isEnabled: workspaceTabCommandsEnabled,
            newSession: { newSessionSheetHost = defaultNewSessionHost },
            closeSelectedTab: { requestClosingTerminal(store.selectedTerminalID) },
            selectAdjacentTab: { store.selectAdjacentTerminal(movingForward: $0) },
            selectTab: { store.selectTerminal(shortcutNumber: $0) },
            separateShownSplit: { if let shownSplit = store.shownSplit { store.separateSplit(shownSplit.id) } },
            closeShownSplitView: { side in
                // The same close request as ⌘W, for the view on that side.
                guard let shownSplit = store.shownSplit, let sides = store.sides(of: shownSplit) else { return }
                requestClosingTerminal(sides.tabID(on: side))
            },
            reverseShownSplit: { if let shownSplit = store.shownSplit { store.reverseSplit(shownSplit.id) } }
        ))
        .background(WorkspaceTabCycleShortcuts(
            isEnabled: workspaceTabCommandsEnabled && !store.terminalSessions.isEmpty,
            onSelectAdjacentTab: { store.selectAdjacentTerminal(movingForward: $0) }
        ))
        .modifier(TerminalTabCloseConfirmation(store: store, closingSessionID: $closingTerminalID))
        .modifier(OnboardingTipsPresenter(
            store: store,
            tour: onboardingTour,
            tipsStore: .shared,
            listsProjectWithSessions: filteredProjection.projects.contains { !$0.conversations.isEmpty },
            readSession: store.selectedTerminalID == nil ? focusedConversation : nil,
            isSidebarShown: !isSidebarHidden,
            isReadyForTips: workspaceTabCommandsEnabled,
            onStartTour: { isSidebarHidden = false }
        ))
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
        newSessionSheetHost == nil && appWideSheet == nil && closingTerminalID == nil
    }

    /// The selected tab's tool, or a terminal when that tab is one; else the tool the sidebar shows, Codex when it shows
    /// every tool. The sheet takes the host's first installed tool instead when the host does not have this one.
    private var newSessionKind: NewSessionKind {
        if let selectedTerminal = store.selectedTerminal {
            return selectedTerminal.provider.map(NewSessionKind.cli) ?? .plainTerminal
        }
        return .cli(providerFilter.provider ?? .codex)
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
