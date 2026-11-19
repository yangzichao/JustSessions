import SwiftUI

struct ConversationSidebarView: View {
    let store: ConversationStore
    @Binding var searchText: String
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    @Binding var statusFilter: SessionStatusFilter
    @Binding var archiveFilter: SessionArchiveFilter
    @Binding var sessionSelection: SessionMultiSelection
    /// Already narrowed by the tool, recency, status, archive, and search filters.
    let projects: [ProjectConversationGroup]
    let allSessionCount: Int
    let recentSessionCount: Int
    let runningSessionCount: Int
    let waitingSessionCount: Int
    let archivedSessionCount: Int
    /// While searching, the first match in each session whose messages hold the search text.
    var messageMatches: [String: SessionMessageMatch] = [:]
    /// While searching, each session's bookmarks whose label or tags hold the search text (SBF-05).
    var bookmarkMatches: [String: [MessageBookmark]] = [:]
    let onNewSession: () -> Void
    let onSelectConversation: (Conversation) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void
    let onCloseTerminal: (UUID) -> Void
    let onCloseTabGroup: ([UUID], _ projectName: String) -> Void
    let onCloseSelectedTabs: ([UUID]) -> Void

    @SceneStorage("sidebarContentMode") private var contentMode: SidebarContentMode = .projects
    @SceneStorage("sidebarOpenTabSearch") private var openTabSearchText = ""
    @State var projectExpansion = ProjectExpansion()
    /// How many sessions each expanded project lists before "Show N more".
    @State var sessionRowLimits = ProjectSessionRowLimits()
    /// Whether sessions offer a chevron that lists their subagents' sessions, set in Settings → General.
    @AppStorage(SidebarSubagentRows.showsSubagentsUserDefaultsKey) var showsSubagents = false
    /// Sessions start with their subagents' sessions hidden; each shows them once you expand it.
    @State var subagentRows = SidebarSubagentRows()
    @State var projectSelection = ProjectMultiSelection()
    /// Rows of Open tabs selected to close together.
    @State var openTabSelection = OpenTabMultiSelection()
    /// A project or session being dragged among the pinned ones.
    @State var pinDrag: SidebarPinDrag?
    @State var sidebarRowFrames = SidebarRowFrames()
    @State private var isAddRemoteHostSheetPresented = false
    /// Asks for a password or code while Connect… on a host's heading logs in.
    @StateObject private var sshLoginPrompter = SSHLoginPrompter()
    /// The host whose archived projects are listed, from its heading's context menu.
    @State private var hostShowingArchivedProjects: SessionHost?
    /// The SSH host a folder path is being typed for, from its heading's +.
    @State private var sshHostAddingProject: SessionHost?
    @State private var sshHostForwardingPort: SessionHost?
    @State private var sshHostEditingSignInCommand: SessionHost?
    /// A project to scroll into view once it is listed: one just added from a host's heading, as a project with no
    /// sessions sorts last under its host and could otherwise be added out of sight, or the onboarding tour's.
    @State var projectToReveal: String?
    /// Set once a deletion of several sessions has run for `deletionProgressBarDelay`, so a quick one never
    /// flashes the progress bar.
    @State private var isDeletionProgressBarShown = false
    @FocusState var isSidebarListFocused: Bool

    static let deletionProgressBarDelay: Duration = .milliseconds(300)

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hostSections: [HostProjectSection] {
        HostProjectSection.sections(hosts: store.hosts, projects: projects)
    }

    /// The project the onboarding tour shows sessions in: the first listed one that has any.
    var onboardingTourProjectID: String? {
        hostSections.lazy.flatMap(\.projects).first { !$0.conversations.isEmpty }?.id
    }

    private var visibleProjectIDs: [String] {
        hostSections.flatMap { $0.projects.map(\.id) }
    }

    private var listedProjectIDs: Set<String> {
        Set(visibleProjectIDs)
    }

    /// Session rows in the order they appear in the sidebar, used for Shift-click ranges, which leave out the rows
    /// hidden below a project's "Show N more".
    private var visibleConversationIDs: [String] {
        hostSections
            .flatMap(\.projects)
            .filter(isExpanded)
            .flatMap { listedSessionRows(of: $0).conversationIDs }
    }

    private var listedConversationIDs: Set<String> {
        Set(projects.flatMap { $0.conversations.map(\.id) })
    }

    /// The session of the tab shown, whose row is highlighted through the tab; none while a filter leaves its row out.
    private var listedConversationIDShownThroughTab: String? {
        guard let conversationID = store.selectedTerminal?.conversation?.id,
            listedConversationIDs.contains(conversationID)
        else { return nil }
        return conversationID
    }

    var selectedConversations: [Conversation] {
        // Nothing selected is the common case, and this runs on every render, so it skips the walk of every row.
        guard !sessionSelection.selectedConversationIDs.isEmpty else { return [] }
        return projects.flatMap(\.conversations).filter { sessionSelection.contains($0.id) }
    }

    var body: some View {
        let selectedConversations = selectedConversations

        VStack(alignment: .leading, spacing: 0) {
            SidebarHeader(
                store: store,
                searchText: contentMode == .projects ? $searchText : $openTabSearchText,
                contentMode: contentMode,
                onNewSession: onNewSession
            )
            HStack(spacing: 6) {
                SidebarContentPicker(selection: $contentMode, openTabCount: store.terminalSessions.count)
                SidebarProjectFilterMenu(
                    recencyFilter: $recencyFilter,
                    providerFilter: $providerFilter,
                    statusFilter: $statusFilter,
                    archiveFilter: $archiveFilter,
                    offeredProviders: store.filterableProviders,
                    allSessionCount: allSessionCount,
                    recentSessionCount: recentSessionCount,
                    runningSessionCount: runningSessionCount,
                    waitingSessionCount: waitingSessionCount,
                    archivedSessionCount: archivedSessionCount
                )
                .opacity(contentMode == .projects ? 1 : 0)
                .allowsHitTesting(contentMode == .projects)
                .disabled(contentMode != .projects)
                .accessibilityHidden(contentMode != .projects)
            }
            .padding(.horizontal, 12)

            SidebarContentPanels(selection: contentMode) {
                projectList
            } openTabs: {
                SidebarOpenTabsView(
                    store: store,
                    searchText: openTabSearchText,
                    selection: $openTabSelection,
                    onSelectTab: selectTab,
                    onDroppedTabIntoTerminals: clearSelectionForDroppedRow,
                    onRenameConversation: onRenameConversation,
                    onCloseTab: onCloseTerminal,
                    onDeleteConversation: { onRequestDeletion(.conversation($0)) },
                    onCloseTabGroup: onCloseTabGroup,
                    onCloseSelectedTabs: onCloseSelectedTabs,
                    onNewSession: onNewSession
                )
            }

            SidebarRandomTip()

            if isDeletionProgressBarShown {
                ThemeDivider()
                SidebarDeletionProgressBar(progress: store.deletionProgress, onCancel: store.cancelDeletion)
            }
            if contentMode == .projects, projectSelection.hasMultipleSelected {
                ThemeDivider()
                SidebarProjectSelectionActionBar(
                    selectedCount: projectSelection.selectedProjectIDs.count,
                    onRemove: removeSelectedProjects,
                    onRemoveAndDeleteSessions: requestRemovalOfSelectedProjectsAndTheirSessions
                )
            } else if contentMode == .projects && sessionSelection.hasMultipleSelected
                && !selectedConversations.allSatisfy(store.isDeletionPending(for:))
            {
                // Hidden while every selected session is already being deleted, as after deleting the selection.
                ThemeDivider()
                SidebarSelectionActionBar(
                    selectedCount: sessionSelection.selectedConversationIDs.count,
                    endableCount: selectedConversations.filter(store.canEndSession).count,
                    onEnd: { store.endSessions(selectedConversations) },
                    onDelete: { onRequestDeletion(.conversations(selectedConversations)) }
                )
            } else if contentMode == .openTabs, openTabSelection.hasMultipleSelected {
                ThemeDivider()
                SidebarOpenTabSelectionActionBar(
                    selectedCount: openTabSelection.selectedTabIDs.count,
                    onClose: { onCloseSelectedTabs(Array(openTabSelection.selectedTabIDs)) }
                )
            }

            ThemeDivider()
            SidebarFooter(
                onAddRemoteHost: { isAddRemoteHostSheetPresented = true }
            )
        }
        .background(sidebarBackground)
        .sheet(isPresented: $isAddRemoteHostSheetPresented) {
            AddRemoteHostSheet(store: store)
                .appLanguage(from: .shared)
        }
        .dismissesOnClickOutside(isPresented: $isAddRemoteHostSheetPresented)
        .sheet(item: $hostShowingArchivedProjects) { host in
            ArchivedProjectsSheet(store: store, host: host)
        }
        .dismissesOnClickOutside(item: $hostShowingArchivedProjects)
        .sheet(item: $sshHostAddingProject) { host in
            AddProjectOnSSHHostSheet(store: store, host: host, onAdded: revealAddedProject)
        }
        .dismissesOnClickOutside(item: $sshHostAddingProject)
        .sheet(item: $sshHostForwardingPort) { host in
            if let destination = host.sshDestination {
                ForwardPortSheet(host: destination)
                    .appLanguage(from: .shared)
            }
        }
        .dismissesOnClickOutside(item: $sshHostForwardingPort)
        .sheet(item: $sshHostEditingSignInCommand) { host in
            if let destination = host.sshDestination {
                RemoteSignInCommandSheet(host: destination, needsLogIn: store.sshHostsNeedingLogIn.contains(destination))
                    .appLanguage(from: .shared)
            }
        }
        .dismissesOnClickOutside(item: $sshHostEditingSignInCommand)
        .remoteSignInQuestions(in: store)
        .sshLoginQuestions(from: sshLoginPrompter)
        .modifier(HostDisconnectConfirmation(store: store))
        .onAppear { expandProjectsWithOpenTerminals() }
        .onOnboardingTourStop(showOnboardingTourStop)
        .onChange(of: contentMode) { _, _ in
            isSidebarListFocused = false
            dismissSidebarSelection()
        }
        .onChange(of: store.terminalSessions.map(\.id)) { _, _ in
            expandProjectsWithOpenTerminals()
        }
        .onChange(of: listedConversationIDs) { _, newListedConversationIDs in
            // Rows hidden by a filter or search, or deleted, leave the selection so actions only touch listed rows.
            sessionSelection.keepOnly(newListedConversationIDs)
        }
        .onChange(of: listedProjectIDs) { _, newListedProjectIDs in
            projectSelection.keepOnly(newListedProjectIDs)
        }
        .modifier(HiddenShownSessionReveal(hiddenShownSession: { hiddenShownSession }, reveal: reveal))
        .task(id: store.isDeletingSeveralSessions) {
            guard store.isDeletingSeveralSessions else {
                isDeletionProgressBarShown = false
                return
            }
            do { try await Task.sleep(for: Self.deletionProgressBarDelay) } catch { return }
            // A deletion ending right at the delay can resume the sleep just before the task is cancelled;
            // showing the bar then would leave it stuck at "0 of 0", as nothing restarts this task.
            guard !Task.isCancelled, store.isDeletingSeveralSessions else { return }
            isDeletionProgressBarShown = true
        }
    }

    /// The theme's sidebar surface, reaching up behind the title bar, sets the list apart from the detail.
    private var sidebarBackground: some View {
        Rectangle().fill(ThemePalette.sidebarSurface).ignoresSafeArea()
    }

    func hostHeading(for section: HostProjectSection) -> some View {
        SidebarHostHeading(
            host: section.host,
            refreshStatus: store.hostRefreshStatuses[section.host],
            copyStep: store.remoteSessionCopySteps[section.host],
            projectCount: section.projects.count,
            onAddProject: { addProject(on: section.host) },
            onRefresh: { store.refreshTryingAgain(section.host) },
            isRefreshDisabled: store.isDeletingSessions,
            archivedProjectCount: store.archivedProjectCount(on: section.host),
            onShowArchivedProjects: { hostShowingArchivedProjects = section.host },
            sshHostActions: section.host.sshDestination.map { destination in
                SidebarSSHHostActions(
                    usesTmuxPrefix: Binding(
                        get: { store.usesTmuxPrefix(on: section.host) },
                        set: { store.setUsesTmuxPrefix($0, on: destination) }
                    ),
                    shellStartupCheck: store.shellStartupCheck(on: destination),
                    onCheckHost: { store.checkHost(destination) },
                    hostCheckProblem: store.hostCheckProblemMessage(on: destination),
                    onShowHostCheck: { store.showHostCheck(destination) },
                    login: sshHostLogin(destination),
                    onConnect: { [sshLoginPrompter] in
                        store.logInFromHeading(to: destination) { await sshLoginPrompter.ask($0) }
                    },
                    onDisconnect: { store.requestDisconnect(destination) },
                    onConnectDisconnectedHost: { store.connectHost(destination) },
                    signIn: RemoteSignIns.shared.command(on: destination) == nil
                        ? nil : RemoteSignIns.shared.state(on: destination),
                    onSignIn: {
                        store.connectIfDisconnected(section.host)
                        RemoteSignIns.shared.signIn(on: destination, presentingIn: store)
                    },
                    onEditSignInCommand: { sshHostEditingSignInCommand = section.host },
                    portForwards: SSHPortForwards.shared.entries(on: destination),
                    onForwardPort: {
                        store.connectIfDisconnected(section.host)
                        sshHostForwardingPort = section.host
                    },
                    onTryPortForwardsAgain: { SSHPortForwards.shared.tryAgain(onlyOn: destination) },
                    onStopPortForward: { SSHPortForwards.shared.stop($0) },
                    onRemove: { store.removeRemoteHost(destination) }
                )
            }
        )
    }

    private func sshHostLogin(_ host: String) -> SidebarSSHHostLogin {
        if store.isDisconnected(host) { return .disconnected }
        if store.sshHostsLoggingIn.contains(host) { return .loggingIn }
        if store.sshHostsLoggedIn.contains(host) { return .loggedIn }
        return .notLoggedIn(needsLogIn: store.sshHostsNeedingLogIn.contains(host))
    }

    /// This Mac's folder is picked in the system's panel; an SSH host's is typed, as nothing can browse it.
    private func addProject(on host: SessionHost) {
        guard host == .thisMac else {
            sshHostAddingProject = host
            return
        }
        ProjectFolderPanel.choose(prompt: AppLocalization.string("Add project")) { folder in
            Task {
                guard let projectPath = try? await store.addProjectToSidebar(folder: folder, on: .thisMac) else { return }
                revealAddedProject(projectPath)
            }
        }
    }

    /// Selects the added project, as a click on it would, and scrolls to it.
    private func revealAddedProject(_ projectPath: String) {
        contentMode = .projects
        isSidebarListFocused = true
        sessionSelection.clear()
        projectSelection.selectOnly(projectPath)
        projectToReveal = projectPath
    }

    func isExpanded(_ project: ProjectConversationGroup) -> Bool {
        projectExpansion.isExpanded(project.id, whileSearching: isSearching)
    }

    /// A subagent's session is only read, so a click on its row, with or without Shift or Command, just shows it.
    func handleConversationClick(_ conversation: Conversation) {
        projectSelection.clear()
        let modifiers = NSEvent.modifierFlags
        if conversation.isSubagent {
            onSelectConversation(conversation)
        } else if modifiers.contains(.shift) {
            isSidebarListFocused = true
            sessionSelection.selectRowShownThroughTabWhileNothingIsSelected(listedConversationIDShownThroughTab)
            sessionSelection.selectRange(to: conversation.id, in: visibleConversationIDs)
        } else if modifiers.contains(.command) {
            isSidebarListFocused = true
            sessionSelection.selectRowShownThroughTabWhileNothingIsSelected(listedConversationIDShownThroughTab)
            sessionSelection.toggle(conversation.id)
        } else {
            onSelectConversation(conversation)
            if NSApp.currentEvent?.clickCount == 2, store.canLaunch(conversation, action: .resume) {
                store.resume(conversation)
            }
        }
    }

    /// Shows the tab's terminal; the rows highlighted for it replace any selection in the list.
    func selectTab(_ terminalID: UUID) {
        projectSelection.clear()
        sessionSelection.clear()
        openTabSelection.clear()
        store.selectTerminal(terminalID)
    }

    /// A row dragged onto the terminals shows there in a tab, so, as for a tab selected, the rows highlighted for the
    /// tabs shown replace any selection in the list.
    func clearSelectionForDroppedRow() {
        projectSelection.clear()
        sessionSelection.clear()
        openTabSelection.clear()
    }

    func handleProjectClick(_ project: ProjectConversationGroup) {
        isSidebarListFocused = true
        sessionSelection.clear()
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift) {
            projectSelection.selectRange(to: project.id, in: visibleProjectIDs)
        } else if modifiers.contains(.command) {
            projectSelection.toggle(project.id)
        } else {
            projectSelection.selectOnly(project.id)
            toggleExpansion(of: project.id)
        }
    }

    func dismissSidebarSelection() {
        projectSelection.clear()
        openTabSelection.clear()
        if sessionSelection.hasMultipleSelected {
            sessionSelection.clear()
        }
    }

    func removeSelectedProjects() {
        store.removeProjectsFromSidebar(projectSelection.selectedProjectIDs.intersection(listedProjectIDs))
        projectSelection.clear()
    }

    /// Asks to confirm first; once confirmed, the archived projects leave the list and so the selection.
    func requestRemovalOfSelectedProjectsAndTheirSessions() {
        onRequestDeletion(.selectedProjectsRemoval(projectSelection.selectedProjectIDs.intersection(listedProjectIDs)))
    }

    /// A tour stop among the projects needs the project list in front, with the tour's project in sight and, for its
    /// sessions, open.
    private func showOnboardingTourStop(_ stop: OnboardingTourStop) {
        guard stop.isTourStopInProjectList else { return }
        contentMode = .projects
        guard let onboardingTourProjectID else { return }
        if stop == .sessions { projectExpansion.expand([onboardingTourProjectID]) }
        projectToReveal = onboardingTourProjectID
    }

    private func expandProjectsWithOpenTerminals() {
        projectExpansion.expand(store.terminalSessions.map(\.projectDirectoryKey))
    }
}
