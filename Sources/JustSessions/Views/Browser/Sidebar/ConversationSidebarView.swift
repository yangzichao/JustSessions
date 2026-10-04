import SwiftUI

struct ConversationSidebarView: View {
    @ObservedObject var store: ConversationStore
    @Binding var searchText: String
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    @Binding var sessionSelection: SessionMultiSelection
    /// Already narrowed by the tool, recency, and search filters.
    let projects: [ProjectConversationGroup]
    let allSessionCount: Int
    let recentSessionCount: Int
    let onNewSession: () -> Void
    let onSelectConversation: (Conversation) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void
    let onCloseTerminal: (UUID) -> Void

    @State private var projectExpansion = ProjectExpansion()
    @State private var projectSelection = ProjectMultiSelection()
    @State private var isAddRemoteHostSheetPresented = false
    /// The host whose archived projects are listed, from its heading's context menu.
    @State private var hostShowingArchivedProjects: SessionHost?
    /// The SSH host a folder path is being typed for, from its heading's +.
    @State private var sshHostAddingProject: SessionHost?
    /// A project just added from a host's heading, scrolled into view once it is listed. A project with no sessions
    /// sorts last under its host, so it could otherwise be added out of sight.
    @State private var projectToReveal: String?
    /// Set once a deletion of several sessions has run for `deletionProgressBarDelay`, so a quick one never
    /// flashes the progress bar.
    @State private var isDeletionProgressBarShown = false
    @FocusState private var isSidebarListFocused: Bool

    static let deletionProgressBarDelay: Duration = .milliseconds(300)

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hostSections: [HostProjectSection] {
        HostProjectSection.sections(hosts: store.hosts, projects: projects)
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

    private var selectedConversations: [Conversation] {
        // Nothing selected is the common case, and this runs on every render, so it skips the walk of every row.
        guard !sessionSelection.selectedConversationIDs.isEmpty else { return [] }
        return projects.flatMap(\.conversations).filter { sessionSelection.contains($0.id) }
    }

    var body: some View {
        let selectedConversations = selectedConversations

        VStack(alignment: .leading, spacing: 0) {
            SidebarHeader(searchText: $searchText, onNewSession: onNewSession)
            SidebarFilterBar(
                recencyFilter: $recencyFilter,
                providerFilter: $providerFilter,
                offeredProviders: store.filterableProviders,
                allSessionCount: allSessionCount,
                recentSessionCount: recentSessionCount
            )

            if !store.terminalSessions.isEmpty {
                SidebarOpenTabsSection(store: store, onSelectTab: selectTab, onCloseTab: onCloseTerminal)
                ThemeDivider()
            }

            ScrollViewReader { scrollProxy in
                SidebarSelectionScrollView(
                    isFocused: $isSidebarListFocused,
                    onDismissSelection: dismissSidebarSelection
                ) {
                    LazyVStack(alignment: .leading, spacing: SidebarIndentGuide.rowSpacing) {
                        ForEach(hostSections) { section in
                            hostHeading(for: section)
                                .padding(.top, 14)
                                .padding(.bottom, 4)

                            if section.projects.isEmpty {
                                SidebarEmptyHostNote(message: SidebarEmptyHostMessage(
                                    host: section.host,
                                    refreshStatus: store.hostRefreshStatuses[section.host],
                                    isSearching: isSearching,
                                    recencyFilter: recencyFilter
                                ))
                            }

                            let parentLabels = ProjectParentLabels(projectsOnOneHost: section.projects)
                            ForEach(section.projects) { project in
                                SidebarProjectSection(
                                    store: store,
                                    project: project,
                                    parentLabel: parentLabels.label(for: project),
                                    isExpanded: isExpanded(project),
                                    projectSelection: projectSelection,
                                    sessionSelection: sessionSelection,
                                    selectedConversations: selectedConversations,
                                    onToggleExpansion: { projectExpansion.toggle(project.id) },
                                    onClickProject: { handleProjectClick(project) },
                                    onNewSession: { provider in
                                        store.launchNewSessionFromProject(provider: provider, projectPath: project.projectPath)
                                    },
                                    onClickConversation: handleConversationClick,
                                    onSelectPendingNewSession: selectTab,
                                    onRenameConversation: onRenameConversation,
                                    onRenameProject: { onRenameProject(project) },
                                    onRemoveSelectedProjects: removeSelectedProjects,
                                    onRequestDeletion: onRequestDeletion
                                )
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .task(id: projectToReveal) {
                    guard let projectToReveal else { return }
                    withAnimation { scrollProxy.scrollTo(projectToReveal, anchor: .center) }
                    self.projectToReveal = nil
                }
            }

            if isDeletionProgressBarShown {
                ThemeDivider()
                SidebarDeletionProgressBar(progress: store.deletionProgress, onCancel: store.cancelDeletion)
            }
            if projectSelection.hasMultipleSelected {
                ThemeDivider()
                SidebarProjectSelectionActionBar(
                    selectedCount: projectSelection.selectedProjectIDs.count,
                    onRemove: removeSelectedProjects
                )
            } else if sessionSelection.hasMultipleSelected && !isDeletionProgressBarShown {
                ThemeDivider()
                SidebarSelectionActionBar(
                    selectedCount: sessionSelection.selectedConversationIDs.count,
                    isDeleteDisabled: !store.canStartDeletion(of: selectedConversations),
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
        .task(id: store.isDeletingSessions) {
            // One session has nothing to cancel between, so only a deletion of several shows the bar.
            guard store.isDeletingSessions, store.pendingDeletionConversationIDs.count > 1 else {
                isDeletionProgressBarShown = false
                return
            }
            do { try await Task.sleep(for: Self.deletionProgressBarDelay) } catch { return }
            isDeletionProgressBarShown = true
        }
    }

    /// The theme's sidebar surface, reaching up behind the title bar, sets the list apart from the detail.
    private var sidebarBackground: some View {
        Rectangle().fill(ThemePalette.sidebarSurface).ignoresSafeArea()
    }

    private func hostHeading(for section: HostProjectSection) -> some View {
        SidebarHostHeading(
            host: section.host,
            refreshStatus: store.hostRefreshStatuses[section.host],
            projectCount: section.projects.count,
            onAddProject: { addProject(on: section.host) },
            onRefresh: { store.refresh(section.host) },
            isRefreshDisabled: store.isDeletingSessions,
            archivedProjectCount: store.archivedProjectPaths(on: section.host).count,
            onShowArchivedProjects: { hostShowingArchivedProjects = section.host },
            onRemove: section.host.sshDestination.map { destination in { store.removeRemoteHost(destination) } }
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
        isSidebarListFocused = true
        sessionSelection.clear()
        projectSelection.selectOnly(projectPath)
        projectToReveal = projectPath
    }

    private func isExpanded(_ project: ProjectConversationGroup) -> Bool {
        projectExpansion.isExpanded(project.id, whileSearching: isSearching)
    }

    private func handleConversationClick(_ conversation: Conversation) {
        projectSelection.clear()
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift) {
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
    private func selectTab(_ terminalID: UUID) {
        projectSelection.clear()
        sessionSelection.clear()
        store.selectTerminal(terminalID)
    }

    private func handleProjectClick(_ project: ProjectConversationGroup) {
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

    private func dismissSidebarSelection() {
        projectSelection.clear()
        if sessionSelection.hasMultipleSelected {
            sessionSelection.clear()
        }
    }

    private func removeSelectedProjects() {
        store.removeProjectsFromSidebar(projectSelection.selectedProjectIDs.intersection(listedProjectIDs))
        projectSelection.clear()
    }

    private func expandProjectsWithOpenTerminals() {
        projectExpansion.expand(store.terminalSessions.map(\.projectDirectoryKey))
    }
}
