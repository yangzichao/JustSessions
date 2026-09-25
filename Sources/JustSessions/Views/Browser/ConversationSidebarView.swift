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
    let onSelectConversation: (Conversation) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onDeleteConversation: (Conversation) -> Void
    let onDeleteConversations: ([Conversation]) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onDeleteProjectSessions: (String) -> Void

    @State private var expandedProjectPaths: Set<String> = []
    @State private var isRemoteHostsSheetPresented = false

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var repeatedProjectNames: Set<String> {
        Set(Dictionary(grouping: projects, by: \.displayName)
            .filter { $0.value.count > 1 }
            .map(\.key))
    }

    /// Session rows in the order they appear in the sidebar, used for Shift-click ranges.
    private var visibleConversationIDs: [String] {
        projects
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
        let repeatedNames = repeatedProjectNames
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
                    SidebarSectionHeading(title: "PROJECTS", count: projects.count)
                        .padding(.top, 14)

                    if projects.isEmpty {
                        Text(emptyProjectsMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                    }

                    ForEach(projects) { project in
                        SidebarProjectSection(
                            store: store,
                            project: project,
                            parentLabel: repeatedNames.contains(project.displayName)
                                ? projectParentLabel(project.projectPath) : nil,
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
                .padding(.bottom, 12)
            }

            if sessionSelection.hasMultipleSelected {
                ThemeDivider()
                SidebarSelectionActionBar(
                    selectedCount: sessionSelection.selectedConversationIDs.count,
                    isDeleteDisabled: store.isLoading || store.isDeletingSessions,
                    onClear: { sessionSelection.clear() },
                    onDelete: { onDeleteConversations(selectedConversations) }
                )
            }

            ThemeDivider()
            SidebarFooter(
                store: store,
                onManageRemoteHosts: { isRemoteHostsSheetPresented = true },
                onCheckForUpdates: onCheckForUpdates
            )
        }
        .background(sidebarBackground)
        .sheet(isPresented: $isRemoteHostsSheetPresented) {
            RemoteHostsSheet(store: store)
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

    private var emptyProjectsMessage: String {
        if store.isLoading && store.conversations.isEmpty { return "Scanning sessions…" }
        if isSearching { return "No matching projects or sessions" }
        return recencyFilter == .recent ? "No sessions in the past seven days" : "No sessions"
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

    private func projectParentLabel(_ projectPath: String) -> String {
        let folderPath = RemoteProjectKey.location(ofKey: projectPath)?.projectPath ?? projectPath
        let parent = URL(fileURLWithPath: folderPath).deletingLastPathComponent()
        return parent.pathComponents.suffix(2).joined(separator: "/")
    }

    private func expandProjectsWithOpenTerminals() {
        for terminal in store.terminalSessions {
            expandedProjectPaths.insert(terminal.projectDirectoryKey)
        }
    }
}
