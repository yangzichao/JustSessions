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
            brand
            SidebarSearchField(
                text: $searchText,
                placeholder: "Search projects and sessions",
                accessibilityLabel: "Search projects by name or path and sessions by title or ID"
            )
            Button(action: onNewSession) {
                Label("New session", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.top, 12)

            VStack(spacing: 2) {
                filterRow("All sessions", symbol: "square.stack", count: allSessionCount, filter: .all)
                filterRow("Recent", symbol: "clock", count: recentSessionCount, filter: .recent)
                toolFilterRow
            }
            .padding(.horizontal, 8)
            .padding(.top, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if !store.terminalSessions.isEmpty {
                        sectionHeading("OPEN TERMINALS", count: store.terminalSessions.count)
                            .padding(.top, 22)
                        ForEach(store.terminalSessions) { terminal in
                            TerminalSidebarRow(
                                session: terminal,
                                projectDisplayName: store.projectDisplayName(forProjectPath: terminal.projectDirectoryKey),
                                isSelected: store.selectedTerminalID == terminal.id,
                                onSelect: { store.selectTerminal(terminal.id) }
                            )
                        }
                        .padding(.horizontal, 8)
                    }

                    sectionHeading("PROJECTS", count: projects.count)
                        .padding(.top, store.terminalSessions.isEmpty ? 26 : 22)

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
                .padding(.bottom, 14)
            }

            if sessionSelection.hasMultipleSelected {
                Divider()
                SidebarSelectionActionBar(
                    selectedCount: sessionSelection.selectedConversationIDs.count,
                    isDeleteDisabled: store.isLoading || store.isDeletingSessions,
                    onClear: { sessionSelection.clear() },
                    onDelete: { onDeleteConversations(selectedConversations) }
                )
            }

            Divider()
            HStack {
                remoteHostsButton
                Spacer()
                Button(action: onCheckForUpdates) {
                    Label("Update", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help("Check for updates")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var emptyProjectsMessage: String {
        if store.isLoading && store.conversations.isEmpty { return "Scanning sessions…" }
        if isSearching { return "No matching projects or sessions" }
        return recencyFilter == .recent ? "No sessions in the past seven days" : "No sessions"
    }

    private var remoteHostsButton: some View {
        Button { isRemoteHostsSheetPresented = true } label: {
            HStack(spacing: 5) {
                Label("Remote", systemImage: "network")
                if store.isSyncingRemoteHosts {
                    ProgressView().controlSize(.mini)
                } else if store.hasRemoteHostFailure {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
        }
        .buttonStyle(.borderless)
        .help(store.hasRemoteHostFailure ? "A remote host could not be reached" : "Manage remote hosts")
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text("JustSessions").font(.system(size: 15, weight: .semibold))
                Text("SESSION LIBRARY")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if store.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Button { store.refreshIncludingRemoteHosts() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isDeletingSessions)
                .help("Refresh sessions")
                .accessibilityLabel("Refresh sessions")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private func sectionHeading(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).tracking(1)
            Spacer()
            Text("\(count)")
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func filterRow(
        _ title: String,
        symbol: String,
        count: Int,
        filter: SessionRecencyFilter
    ) -> some View {
        let isSelected = recencyFilter == filter
        return Button { recencyFilter = filter } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 13)).frame(width: 17)
                Text(title)
                Spacer(minLength: 4)
                Text("\(count)").font(.caption).foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var toolFilterRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease").font(.system(size: 13)).frame(width: 17)
            Text("Tool")
            Spacer(minLength: 4)
            Picker("Tool", selection: $providerFilter) {
                ForEach(ConversationProviderFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 32)
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
