import SwiftUI

struct ConversationSidebarView: View {
    let store: ConversationStore
    @Binding var searchText: String
    @Binding var searchScope: SidebarSearchScope
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    @Binding var statusFilter: SessionStatusFilter
    @Binding var archiveFilter: SessionArchiveFilter
    @Binding var sessionSelection: SessionMultiSelection
    let projects: [ProjectConversationGroup]
    let allSessionCount: Int
    let recentSessionCount: Int
    let runningSessionCount: Int
    let waitingSessionCount: Int
    let archivedSessionCount: Int
    var messageMatches: [String: SessionMessageMatch] = [:]
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
    @State var sessionRowLimits = ProjectSessionRowLimits()
    @AppStorage(SidebarSubagentRows.showsSubagentsUserDefaultsKey) var showsSubagents = false
    @State var subagentRows = SidebarSubagentRows()
    @State var projectSelection = ProjectMultiSelection()
    @State var openTabSelection = OpenTabMultiSelection()
    @State var pinDrag: SidebarPinDrag?
    @State var sidebarRowFrames = SidebarRowFrames()
    @State private var isAddRemoteHostSheetPresented = false
    @StateObject private var sshLoginPrompter = SSHLoginPrompter()
    @State private var hostShowingArchivedProjects: SessionHost?
    @State private var sshHostAddingProject: SessionHost?
    @State private var sshHostForwardingPort: SessionHost?
    @State private var sshHostEditingSignInCommand: SessionHost?
    @State var projectToReveal: String?
    @State private var isDeletionProgressBarShown = false
    @FocusState var isSidebarListFocused: Bool

    static let deletionProgressBarDelay: Duration = .milliseconds(300)

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hostSections: [HostProjectSection] {
        HostProjectSection.sections(hosts: store.hosts, projects: projects)
    }

    var onboardingTourProjectID: String? {
        hostSections.lazy.flatMap(\.projects).first { !$0.conversations.isEmpty }?.id
    }

    private var visibleProjectIDs: [String] {
        hostSections.flatMap { $0.projects.map(\.id) }
    }

    private var listedProjectIDs: Set<String> {
        Set(visibleProjectIDs)
    }

    private var visibleConversationIDs: [String] {
        hostSections
            .flatMap(\.projects)
            .filter(isExpanded)
            .flatMap { listedSessionRows(of: $0).conversationIDs }
    }

    private var listedConversationIDs: Set<String> {
        Set(projects.flatMap { $0.conversations.map(\.id) })
    }

    private var listedConversationIDShownThroughTab: String? {
        guard let conversationID = store.selectedTerminal?.conversation?.id,
            listedConversationIDs.contains(conversationID)
        else { return nil }
        return conversationID
    }

    var selectedConversations: [Conversation] {
        guard !sessionSelection.selectedConversationIDs.isEmpty else { return [] }
        return projects.flatMap(\.conversations).filter { sessionSelection.contains($0.id) }
    }

    var body: some View {
        let selectedConversations = selectedConversations

        VStack(alignment: .leading, spacing: 0) {
            SidebarHeader(
                store: store,
                searchText: contentMode == .projects ? $searchText : $openTabSearchText,
                searchScope: contentMode == .projects ? $searchScope : nil,
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
            guard !Task.isCancelled, store.isDeletingSeveralSessions else { return }
            isDeletionProgressBarShown = true
        }
    }

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

    func selectTab(_ terminalID: UUID) {
        projectSelection.clear()
        sessionSelection.clear()
        openTabSelection.clear()
        store.selectTerminal(terminalID)
    }

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

    func requestRemovalOfSelectedProjectsAndTheirSessions() {
        onRequestDeletion(.selectedProjectsRemoval(projectSelection.selectedProjectIDs.intersection(listedProjectIDs)))
    }

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
