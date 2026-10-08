import SwiftUI

struct ConversationSidebarView: View {
    @ObservedObject var store: ConversationStore
    @Binding var searchText: String
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    @Binding var waitingFilter: SessionWaitingFilter
    @Binding var sessionSelection: SessionMultiSelection
    /// Already narrowed by the tool, recency, waiting, and search filters.
    let projects: [ProjectConversationGroup]
    let allSessionCount: Int
    let recentSessionCount: Int
    let waitingSessionCount: Int
    /// While searching, the first match in each session whose messages hold the search text.
    var messageMatches: [String: SessionMessageMatch] = [:]
    let onNewSession: () -> Void
    let onSelectConversation: (Conversation) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void
    let onCloseTerminal: (UUID) -> Void

    @SceneStorage("sidebarContentMode") private var contentMode: SidebarContentMode = .projects
    @SceneStorage("sidebarOpenTabSearch") private var openTabSearchText = ""
    @State var projectExpansion = ProjectExpansion()
    /// Sessions start with their subagents' sessions hidden; each shows them once you expand it.
    @State var subagentRows = SidebarSubagentRows()
    @State var projectSelection = ProjectMultiSelection()
    @State private var isAddRemoteHostSheetPresented = false
    /// The host whose archived projects are listed, from its heading's context menu.
    @State private var hostShowingArchivedProjects: SessionHost?
    /// The SSH host a folder path is being typed for, from its heading's +.
    @State private var sshHostAddingProject: SessionHost?
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

    /// Session rows in the order they appear in the sidebar, used for Shift-click ranges.
    private var visibleConversationIDs: [String] {
        hostSections
            .flatMap(\.projects)
            .filter(isExpanded)
            .flatMap { $0.conversations.map(\.id) }
    }

    private var listedConversationIDs: Set<String> {
        Set(projects.flatMap { $0.conversations.map(\.id) })
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
                searchText: contentMode == .projects ? $searchText : $openTabSearchText,
                contentMode: contentMode,
                onNewSession: onNewSession
            )
            HStack(spacing: 6) {
                SidebarContentPicker(selection: $contentMode, openTabCount: store.terminalSessions.count)
                SidebarProjectFilterMenu(
                    recencyFilter: $recencyFilter,
                    providerFilter: $providerFilter,
                    waitingFilter: $waitingFilter,
                    offeredProviders: store.filterableProviders,
                    allSessionCount: allSessionCount,
                    recentSessionCount: recentSessionCount,
                    waitingSessionCount: waitingSessionCount
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
                    onSelectTab: selectTab,
                    onCloseTab: onCloseTerminal,
                    onNewSession: onNewSession
                )
            }

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
                && !selectedConversations.allSatisfy(store.isDeletionPending(for:)) {
                // Hidden while every selected session is already being deleted, as after deleting the selection.
                ThemeDivider()
                SidebarSelectionActionBar(
                    selectedCount: sessionSelection.selectedConversationIDs.count,
                    onDelete: { onRequestDeletion(.conversations(selectedConversations)) }
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
            projectCount: section.projects.count,
            onAddProject: { addProject(on: section.host) },
            onRefresh: { store.refresh(section.host) },
            isRefreshDisabled: store.isDeletingSessions,
            archivedProjectCount: store.archivedProjectPaths(on: section.host).count,
            onShowArchivedProjects: { hostShowingArchivedProjects = section.host },
            sshHostActions: section.host.sshDestination.map { destination in
                SidebarSSHHostActions(
                    usesTmuxPrefix: Binding(
                        get: { store.usesTmuxPrefix(on: section.host) },
                        set: { store.setUsesTmuxPrefix($0, on: destination) }
                    ),
                    onRemove: { store.removeRemoteHost(destination) }
                )
            }
        )
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
            sessionSelection.selectRange(to: conversation.id, in: visibleConversationIDs)
        } else if modifiers.contains(.command) {
            isSidebarListFocused = true
            sessionSelection.toggle(conversation.id)
        } else {
            onSelectConversation(conversation)
            if NSApp.currentEvent?.clickCount == 2, store.canLaunch(conversation, action: .resume) {
                store.launch(conversation, action: .resume)
            }
        }
    }

    /// Shows the tab's terminal; the rows highlighted for it replace any selection in the list.
    func selectTab(_ terminalID: UUID) {
        projectSelection.clear()
        sessionSelection.clear()
        store.selectTerminal(terminalID)
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
            projectExpansion.toggle(project.id)
        }
    }

    func dismissSidebarSelection() {
        projectSelection.clear()
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
