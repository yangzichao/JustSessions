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
    let onCheckForUpdates: () -> Void
    let onNewSession: () -> Void
    let onNewSessionOnHost: (SessionHost) -> Void
    let onSelectConversation: (Conversation) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    @State private var projectExpansion = ProjectExpansion()
    @State private var isAddRemoteHostSheetPresented = false

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hostSections: [HostProjectSection] {
        HostProjectSection.sections(hosts: store.hosts, projects: projects)
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
        projects.flatMap(\.conversations).filter { sessionSelection.contains($0.id) }
    }

    var body: some View {
        let selectedConversations = selectedConversations

        VStack(alignment: .leading, spacing: 0) {
            SidebarHeader(store: store)
            SidebarNewSessionButton(action: onNewSession)
            SidebarSearchField(
                text: $searchText,
                placeholder: "Search projects and sessions",
                accessibilityLabel: "Search projects by name or path and sessions by title or ID"
            )
            .padding(.top, 8)
            SidebarFilterBar(
                recencyFilter: $recencyFilter,
                providerFilter: $providerFilter,
                allSessionCount: allSessionCount,
                recentSessionCount: recentSessionCount
            )
            .padding(.top, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
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
                                sessionSelection: sessionSelection,
                                selectedConversations: selectedConversations,
                                onToggle: { projectExpansion.toggle(project.id) },
                                onNewSession: { provider in
                                    store.launchNewSessionFromProject(provider: provider, projectPath: project.projectPath)
                                },
                                onClickConversation: handleConversationClick,
                                onSelectPendingNewSession: { terminalID in
                                    sessionSelection.clear()
                                    store.selectTerminal(terminalID)
                                },
                                onRenameConversation: onRenameConversation,
                                onClearSessionSelection: { sessionSelection.clear() },
                                onRenameProject: { onRenameProject(project) },
                                onRequestDeletion: onRequestDeletion
                            )
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 12)
            }

            if sessionSelection.hasMultipleSelected {
                ThemeDivider()
                SidebarSelectionActionBar(
                    selectedCount: sessionSelection.selectedConversationIDs.count,
                    isDeleteDisabled: !store.canStartDeletion,
                    onClear: { sessionSelection.clear() },
                    onDelete: { onRequestDeletion(.conversations(selectedConversations)) }
                )
            }

            ThemeDivider()
            SidebarFooter(
                onAddRemoteHost: { isAddRemoteHostSheetPresented = true },
                onCheckForUpdates: onCheckForUpdates
            )
        }
        .background(sidebarBackground)
        .sheet(isPresented: $isAddRemoteHostSheetPresented) {
            AddRemoteHostSheet(store: store)
        }
        .onAppear { expandProjectsWithOpenTerminals() }
        .onChange(of: store.terminalSessions.map(\.id)) { _, _ in
            expandProjectsWithOpenTerminals()
        }
        .onChange(of: listedConversationIDs) { _, newListedConversationIDs in
            // Rows hidden by a filter or search, or deleted, leave the selection so actions only touch listed rows.
            sessionSelection.keepOnly(newListedConversationIDs)
        }
    }

    /// The theme's sidebar surface, reaching up behind the title bar, sets the list apart from the detail.
    private var sidebarBackground: some View {
        Rectangle().fill(ThemePalette.sidebarSurface).ignoresSafeArea()
    }

    private func hostHeading(for section: HostProjectSection) -> some View {
        SidebarHostHeading(
            host: section.host,
            isOnlyHost: !store.hasRemoteHosts,
            refreshStatus: store.hostRefreshStatuses[section.host],
            projectCount: section.projects.count,
            onNewSession: { onNewSessionOnHost(section.host) },
            onRefresh: { store.refresh(section.host) },
            onRemove: section.host.sshDestination.map { destination in { store.removeRemoteHost(destination) } }
        )
    }

    private func isExpanded(_ project: ProjectConversationGroup) -> Bool {
        projectExpansion.isExpanded(project.id, whileSearching: isSearching)
    }

    private func handleConversationClick(_ conversation: Conversation) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift) {
            sessionSelection.selectRange(to: conversation.id, in: visibleConversationIDs)
        } else if modifiers.contains(.command) {
            sessionSelection.toggle(conversation.id)
        } else {
            onSelectConversation(conversation)
            if NSApp.currentEvent?.clickCount == 2, store.canLaunch(conversation, action: .resume) {
                store.launch(conversation, action: .resume)
            }
        }
    }

    private func expandProjectsWithOpenTerminals() {
        projectExpansion.expand(store.terminalSessions.map(\.projectDirectoryKey))
    }
}
