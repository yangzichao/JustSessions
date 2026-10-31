import SwiftUI

struct ConversationBrowserView: View {
    let store: ConversationStore
    @Binding var searchText: String
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    @Binding var statusFilter: SessionStatusFilter
    @Binding var archiveFilter: SessionArchiveFilter
    let onRename: (Conversation) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    @State var sessionSelection = SessionMultiSelection()
    /// What this window showed, for Back and Forward; see `WorkspaceNavigationControls`.
    @State var navigationHistory = WorkspaceNavigationHistory()
    @State private var messageSearch = SidebarMessageSearch()
    /// The match a click on a session row found in messages opens the reader at.
    @State private var transcriptMatchReveal: TranscriptMatchReveal?
    /// The host the New Session sheet opened on; nil while it is closed.
    @State private var newSessionSheetHost: SessionHost?
    /// Settings or Help while either shows as a sheet on this window.
    @State private var appWideSheet: AppWideSheet?
    @State private var closingTerminalID: UUID?
    @State private var closingSeveralTabs: SeveralTabsClosingRequest?
    @SceneStorage("isSidebarHidden") private var isSidebarHidden = false
    @StateObject private var updateManager = SparkleUpdateManager()
    @StateObject private var onboardingTour = OnboardingTour()

    /// While searching, each session's bookmarks whose label or tags hold the search text (SBF-05). Bookmarks are read
    /// only while there is text, so ⌘D redraws the browser only during a search.
    private var bookmarkMatches: [String: [MessageBookmark]] {
        guard !searchText.isEmpty, let query = MessageBookmarkQuery(searchText) else { return [:] }
        return store.messageBookmarks.matches(for: query, includingSnippets: false)
    }

    private func makeFilteredProjection(bookmarkMatches: [String: [MessageBookmark]]) -> FilteredSidebarProjection {
        store.filteredSidebarProjection(
            providerFilter: providerFilter,
            recencyFilter: recencyFilter,
            statusFilter: statusFilter,
            archiveFilter: archiveFilter,
            searchText: searchText,
            messageMatchConversationIDs: Set(messageSearch.results.matchesByConversationID.keys).union(bookmarkMatches.keys)
        )
    }

    /// A session a search found by a bookmark's label or tag, or in its messages, opens its reader there, even while its
    /// CLI runs; the bookmark first, since its words were chosen.
    private func selectConversation(_ conversation: Conversation, bookmarkMatches: [String: [MessageBookmark]]) {
        if !searchText.isEmpty, let bookmark = bookmarkMatches[conversation.id]?.first {
            sessionSelection.selectOnly(conversation.id)
            store.selectTerminal(nil)
            transcriptMatchReveal = TranscriptMatchReveal(conversationID: conversation.id, entryID: bookmark.entryID, query: "")
        } else if !searchText.isEmpty, let match = messageSearch.match(for: conversation.id) {
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
        // Nothing in this body reads the selected tab, or anything else a tab switch changes: what does is read in the
        // modifiers and small views below, so a switch redraws them and not the sidebar's every row.
        let bookmarkMatches = bookmarkMatches
        let filteredProjection = makeFilteredProjection(bookmarkMatches: bookmarkMatches)

        ResizableSidebarLayout(isSidebarHidden: isSidebarHidden) {
            ConversationSidebarView(
                store: store,
                searchText: $searchText,
                recencyFilter: $recencyFilter,
                providerFilter: $providerFilter,
                statusFilter: $statusFilter,
                archiveFilter: $archiveFilter,
                sessionSelection: $sessionSelection,
                projects: filteredProjection.projects,
                allSessionCount: filteredProjection.allSessionCount,
                recentSessionCount: filteredProjection.recentSessionCount,
                runningSessionCount: filteredProjection.runningSessionCount,
                waitingSessionCount: filteredProjection.waitingSessionCount,
                archivedSessionCount: filteredProjection.archivedSessionCount,
                messageMatches: searchText.isEmpty ? [:] : messageSearch.results.matchesByConversationID,
                bookmarkMatches: bookmarkMatches,
                onNewSession: { newSessionSheetHost = defaultNewSessionHost },
                onSelectConversation: { selectConversation($0, bookmarkMatches: bookmarkMatches) },
                onRenameConversation: onRename,
                onRenameProject: onRenameProject,
                onRequestDeletion: onRequestDeletion,
                onCloseTerminal: { requestClosingTerminal($0) },
                onCloseTabGroup: { requestClosingTabs($0, subject: .group(projectName: $1)) },
                onCloseSelectedTabs: { requestClosingTabs($0, subject: .selectedTabs) }
            )
        } detail: {
            WorkspaceDetailView(
                store: store,
                sessionSelection: sessionSelection,
                transcriptMatchReveal: transcriptMatchReveal,
                isSidebarHidden: isSidebarHidden,
                onRename: onRename,
                onNewSession: { newSessionSheetHost = defaultNewSessionHost },
                onNewSessionInSplitChooser: { chooserID in
                    store.awaitNewTab(inSplitChooser: chooserID)
                    newSessionSheetHost = defaultNewSessionHost
                },
                onCloseTerminal: { requestClosingTerminal($0) },
                onCloseTabGroup: { requestClosingTabs($0, subject: .group(projectName: $1)) },
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
        .modifier(WorkspaceNavigationControls(
            store: store,
            history: $navigationHistory,
            sessionSelection: $sessionSelection,
            isSidebarHidden: $isSidebarHidden,
            listedConversationIDs: filteredProjection.listedConversationIDs,
            isEnabled: workspaceTabCommandsEnabled
        ))
        .focusedSceneValue(\.isSidebarHidden, $isSidebarHidden)
        .background(SelectedTabTextZoomTarget(store: store))
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
                    try await store.launchNewSession(
                        provider: provider,
                        host: request.host,
                        folder: request.folder,
                        creatingMissingFolder: request.creatingMissingFolder,
                        deletesSessionWhenClosed: request.deletesSessionWhenClosed
                    )
                case .plainTerminal:
                    try await store.openPlainTerminal(
                        host: request.host,
                        folder: request.folder,
                        creatingMissingFolder: request.creatingMissingFolder
                    )
                }
            }
        }
        .dismissesOnClickOutside(item: $newSessionSheetHost)
        // A split chooser's New Session… waits only while the sheet is open; the sheet opens its tab before it closes.
        .onChange(of: newSessionSheetHost == nil) { _, isClosed in
            if isClosed { store.stopAwaitingNewTabInSplitChooser() }
        }
        .sheet(item: hostCheckBinding) { state in
            HostCheckSheet(store: store, presentedState: state)
        }
        .dismissesOnClickOutside(item: hostCheckBinding)
        .showsAppWideSheets($appWideSheet, hosts: store.hosts, onCheckForUpdates: { updateManager.checkForUpdates() })
        .modifier(WorkspaceTabActionsValue(
            store: store,
            isEnabled: workspaceTabCommandsEnabled,
            newSession: { newSessionSheetHost = defaultNewSessionHost },
            requestClosingTab: { requestClosingTerminal($0) }
        ))
        .modifier(TerminalTabCloseConfirmation(
            store: store,
            closingSessionID: $closingTerminalID,
            tabCloseChoiceSettingsStore: .shared,
            plainTerminalCloseChoiceSettingsStore: .shared
        ))
        .modifier(SeveralTabsCloseConfirmation(store: store, request: $closingSeveralTabs))
        .modifier(AllBookmarksPresenter(store: store))
        .modifier(OnboardingTipsPresenter(
            store: store,
            tour: onboardingTour,
            tipsStore: .shared,
            listsProjectWithSessions: filteredProjection.projects.contains { !$0.conversations.isEmpty },
            focusedConversation: focusedConversation,
            isSidebarShown: !isSidebarHidden,
            isReadyForTips: workspaceTabCommandsEnabled,
            onStartTour: { isSidebarHidden = false }
        ))
    }

    /// A tab still waiting to be shown runs nothing, so it closes without asking what to do with its CLI; so does a tab
    /// whose CLI or shell already ended, which also ends the dead tmux session that kept a failed CLI's output. A tab
    /// whose CLI can keep running in tmux, or a plain terminal, closes without asking too once you chose Don't ask
    /// again, doing what you chose: for that tab's host, or for every plain terminal. A tab whose session is deleted
    /// when it closes deletes it without asking: ticking the box in the New session sheet asked.
    private func requestClosingTerminal(_ id: UUID?) {
        guard let id, let closingTab = store.terminalSessions.first(where: { $0.id == id }) else { return }
        guard !store.deletesSessionWhenClosed(closingTab) else {
            store.closeTabDeletingItsSession(id)
            return
        }
        switch closingTab.closingNeed {
        case .nothingStarted:
            store.closeTerminal(id)
        case .alreadyEnded:
            store.closeTerminal(id, endingTmuxSession: true)
        case .canKeepCLIRunning:
            let savedChoice = TabCloseChoiceSettingsStore.shared.choice(for: closingTab.host)
            if let endsTmuxSession = savedChoice.endsTmuxSessionWithoutAsking {
                store.closeTerminal(id, endingTmuxSession: endsTmuxSession)
            } else {
                closingTerminalID = id
            }
        case .plainTerminal where PlainTerminalCloseChoiceSettingsStore.shared.choice == .closeWithoutAsking:
            store.closeTerminal(id)
        case .plainTerminal, .cliStopsWithTab:
            closingTerminalID = id
        }
    }

    /// A group's one tab, or one tab selected, closes as its × closes it, with its own dialog. More ask once for them all,
    /// unless each would close without asking on its own.
    private func requestClosingTabs(_ tabIDs: [UUID], subject: SeveralTabsClosingRequest.Subject) {
        guard tabIDs.count > 1 else {
            requestClosingTerminal(tabIDs.first)
            return
        }
        let question = store.closingQuestion(
            forTabs: tabIDs,
            tabCloseChoices: TabCloseChoiceSettingsStore.shared.choices,
            plainTerminalCloseChoice: PlainTerminalCloseChoiceSettingsStore.shared.choice
        )
        if question == .closeWithoutAsking {
            store.closeTabs(tabIDs, as: TabCloseChoiceSettingsStore.shared.choices)
        } else {
            closingSeveralTabs = SeveralTabsClosingRequest(subject: subject, tabIDs: tabIDs, question: question)
        }
    }

    var workspaceTabCommandsEnabled: Bool {
        newSessionSheetHost == nil && appWideSheet == nil && closingTerminalID == nil && closingSeveralTabs == nil
            && store.hostCheck == nil && store.hostDisconnectQuestion == nil && !store.showsAllBookmarks
    }

    /// Check this host…'s sheet, which the sidebar and an ended tab open through the store.
    private var hostCheckBinding: Binding<HostCheckSheetState?> {
        Binding(get: { store.hostCheck }, set: { store.hostCheck = $0 })
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

/// Text zoom goes to the terminals while a tab shows, and otherwise to the conversation. Read in this view's body, so a
/// tab switch redraws only it rather than the browser.
private struct SelectedTabTextZoomTarget: View {
    let store: ConversationStore

    var body: some View {
        TextZoomTargetReporter(target: store.selectedTerminalID == nil ? .conversation : .terminals)
    }
}

/// The tab commands, which follow the selected tab and the open tabs, and ⌃Tab's shortcuts. Read in this modifier's body,
/// so a tab switch redraws only it rather than the browser.
private struct WorkspaceTabActionsValue: ViewModifier {
    let store: ConversationStore
    /// No sheet, alert, or dialog is up.
    let isEnabled: Bool
    let newSession: () -> Void
    /// Asks to close a tab, as its × does.
    let requestClosingTab: (UUID?) -> Void

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.workspaceTabActions, WorkspaceTabActions(
                tabCount: store.terminalSessions.count,
                hasSelectedTab: store.selectedTerminal != nil,
                isSplitShown: store.isSplitViewShown,
                shownSplitOrientation: store.shownSplitOrientation ?? .sideBySide,
                canOpenSplitChooser: store.canOpenSplitChooser,
                canReopenClosedTab: store.canReopenClosedTab,
                isEnabled: isEnabled,
                newSession: newSession,
                reopenClosedTab: { store.reopenClosedTab() },
                closeSelectedTab: {
                    // The split chooser with the keyboard closes, as ⌘W closes Chrome's split view page.
                    if store.selectsShownSplitChooser, let chooser = store.shownSplitChooser {
                        store.closeSplitChooser(chooser.id)
                    } else {
                        requestClosingTab(store.selectedTerminalID)
                    }
                },
                selectAdjacentTab: { store.selectAdjacentTerminal(movingForward: $0) },
                selectTab: { store.selectTerminal(shortcutNumber: $0) },
                openSplitChooser: { store.openSplitChooser() },
                separateShownSplit: { performOnShownSplitView(.separateViews) },
                // The same close request as ⌘W, for the view on that side.
                closeShownSplitView: { performOnShownSplitView(.closeView($0)) },
                reverseShownSplit: { performOnShownSplitView(.reverseViews) },
                toggleShownSplitOrientation: {
                    performOnShownSplitView(.setOrientation((store.shownSplitOrientation ?? .sideBySide).toggled))
                }
            ))
            .background(WorkspaceTabCycleShortcuts(
                isEnabled: isEnabled && !store.terminalSessions.isEmpty,
                onSelectAdjacentTab: { store.selectAdjacentTerminal(movingForward: $0) }
            ))
    }

    /// The Tabs menu's split view items act on the shown split or split chooser, as the selected tab's own entries do.
    private func performOnShownSplitView(_ action: TerminalTabSplitAction) {
        guard store.isSplitViewShown, let selectedTerminalID = store.selectedTerminalID else { return }
        store.performSplitAction(action, fromTab: selectedTerminalID) { requestClosingTab($0) }
    }
}
