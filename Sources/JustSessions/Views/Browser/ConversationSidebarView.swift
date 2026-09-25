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
    let onDeleteConversation: (Conversation) -> Void
    let onDeleteConversations: ([Conversation]) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onDeleteProjectSessions: (String) -> Void

    @State private var expandedProjectPaths: Set<String> = []
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
                            emptyProjectsMessage(for: section.host)
                        }

                        let repeatedNames = Self.repeatedProjectNames(in: section.projects)
                        ForEach(section.projects) { project in
                            SidebarProjectSection(
                                store: store,
                                project: project,
                                parentLabel: repeatedNames.contains(project.displayName)
                                    ? projectParentLabel(project.location.path) : nil,
                                isExpanded: isExpanded(project),
                                sessionSelection: sessionSelection,
                                selectedConversations: selectedConversations,
                                onToggle: { toggleExpansion(of: project) },
                                onNewSession: { provider in
                                    store.launchNewSessionFromProject(provider: provider, projectPath: project.projectPath)
                                },
                                onClickConversation: handleConversationClick,
                                onSelectPendingNewSession: { terminalID in
                                    sessionSelection.clear()
                                    store.selectTerminal(terminalID)
                                },
                                onRenameConversation: onRenameConversation,
                                onDeleteConversation: onDeleteConversation,
                                onDeleteSelectedConversations: { onDeleteConversations(selectedConversations) },
                                onClearSessionSelection: { sessionSelection.clear() },
                                onRenameProject: { onRenameProject(project) },
                                onDeleteProjectSessions: { onDeleteProjectSessions(project.id) }
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
                    isDeleteDisabled: store.isScanningThisMac || store.isDeletingSessions,
                    onClear: { sessionSelection.clear() },
                    onDelete: { onDeleteConversations(selectedConversations) }
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

    /// Warm stone under the sidebar, reaching up behind the title bar, sets it apart from the paper-colored detail.
    private var sidebarBackground: some View {
        ThemePalette.sidebarSurface.ignoresSafeArea()
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

    /// Why a host lists no projects: its refresh is running or failed, or the filters left nothing.
    private func emptyProjectsMessage(for host: SessionHost) -> some View {
        Group {
            if case .failed(let message)? = store.hostRefreshStatuses[host] {
                Text(message).foregroundStyle(ThemePalette.warning)
            } else {
                Text(emptyProjectsText(for: host)).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }

    private func emptyProjectsText(for host: SessionHost) -> String {
        if store.hostRefreshStatuses[host] == .refreshing {
            return host == .thisMac ? "Scanning sessions…" : "Copying sessions…"
        }
        if isSearching { return "No matching projects or sessions" }
        return recencyFilter == .recent ? "No sessions in the past seven days" : "No sessions"
    }

    /// Names shared by two projects on the same host; those rows add their parent folder. The same name on two
    /// hosts needs nothing, since the headings already tell them apart.
    private static func repeatedProjectNames(in projects: [ProjectConversationGroup]) -> Set<String> {
        Set(Dictionary(grouping: projects, by: \.displayName)
            .filter { $0.value.count > 1 }
            .map(\.key))
    }

    private func isExpanded(_ project: ProjectConversationGroup) -> Bool {
        isSearching || expandedProjectPaths.contains(project.id)
    }

    private func toggleExpansion(of project: ProjectConversationGroup) {
        if expandedProjectPaths.contains(project.id) {
            expandedProjectPaths.remove(project.id)
        } else {
            expandedProjectPaths.insert(project.id)
        }
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

    private func projectParentLabel(_ folderPath: String) -> String {
        let parent = URL(fileURLWithPath: folderPath).deletingLastPathComponent()
        return parent.pathComponents.suffix(2).joined(separator: "/")
    }

    private func expandProjectsWithOpenTerminals() {
        for terminal in store.terminalSessions {
            expandedProjectPaths.insert(terminal.projectDirectoryKey)
        }
    }
}
