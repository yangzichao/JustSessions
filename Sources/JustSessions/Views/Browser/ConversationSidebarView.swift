import SwiftUI

struct ConversationSidebarView: View {
    @ObservedObject var store: ConversationStore
    @Binding var searchText: String
    let selection: ConversationBrowserSelection
    @Binding var sessionSelection: SessionMultiSelection
    let projects: [ProjectConversationGroup]
    let conversationCount: Int
    let recentCount: Int
    let onCheckForUpdates: () -> Void
    let onNewSession: () -> Void
    let onSelect: (ConversationBrowserSelection) -> Void
    let onSelectConversation: (Conversation) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onDeleteConversation: (Conversation) -> Void
    let onDeleteConversations: ([Conversation]) -> Void
    let onRenameProject: (ProjectConversationGroup) -> Void
    let onDeleteProjectSessions: (String) -> Void

    @State private var expandedProjectPaths: Set<String> = []
    @State private var projectSearchText = ""

    private var visibleProjects: [ProjectConversationGroup] {
        let query = projectSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return projects }
        return projects.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.projectPath.localizedCaseInsensitiveContains(query)
        }
    }

    private var repeatedProjectNames: Set<String> {
        Set(Dictionary(grouping: projects, by: \.displayName)
            .filter { $0.value.count > 1 }
            .map(\.key))
    }

    /// Session rows in the order they appear in the sidebar, used for Shift-click ranges.
    private var visibleConversationIDs: [String] {
        visibleProjects
            .filter { expandedProjectPaths.contains($0.id) }
            .flatMap { $0.conversations.map(\.id) }
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
                placeholder: "Search sessions",
                accessibilityLabel: "Search sessions and projects"
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
                navigationRow("All sessions", symbol: "square.stack", count: conversationCount, isSelected: selection == .all) {
                    onSelect(.all)
                }
                navigationRow("Recent", symbol: "clock", count: recentCount, isSelected: selection == .recent) {
                    onSelect(.recent)
                }
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

                    sectionHeading("PROJECTS", count: visibleProjects.count)
                        .padding(.top, store.terminalSessions.isEmpty ? 26 : 22)

                    SidebarSearchField(
                        text: $projectSearchText,
                        placeholder: "Search projects",
                        accessibilityLabel: "Search projects by name or path"
                    )
                    .padding(.bottom, 8)

                    if visibleProjects.isEmpty {
                        Text("No matching projects")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                    }

                    ForEach(visibleProjects) { project in
                        SidebarProjectSection(
                            store: store,
                            project: project,
                            parentLabel: repeatedNames.contains(project.displayName)
                                ? projectParentLabel(project.projectPath) : nil,
                            isExpanded: expandedProjectPaths.contains(project.id),
                            isSelected: selection == .project(project.id),
                            sessionSelection: sessionSelection,
                            selectedConversations: selectedConversations,
                            onToggle: {
                                if expandedProjectPaths.contains(project.id) {
                                    expandedProjectPaths.remove(project.id)
                                } else {
                                    expandedProjectPaths.insert(project.id)
                                }
                                onSelect(.project(project.id))
                            },
                            onNewSession: { provider in
                                store.launchNewSessionFromProject(provider: provider, projectPath: project.projectPath)
                            },
                            onClickConversation: handleConversationClick,
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
                Text("Claude Code  ·  Codex")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .onAppear { expandProjectsWithOpenTerminals() }
        .onChange(of: store.terminalSessions.map(\.id)) { _, _ in
            expandProjectsWithOpenTerminals()
        }
        .onChange(of: selection) { _, newSelection in
            if case .project(let path) = newSelection { expandedProjectPaths.insert(path) }
        }
        .onChange(of: visibleConversationIDs) { _, newVisibleConversationIDs in
            // Collapsed, filtered, or deleted rows leave the selection so a batch delete only touches visible rows.
            sessionSelection.keepOnly(Set(newVisibleConversationIDs))
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
        }
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

    private func navigationRow(
        _ title: String,
        symbol: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
    }

    private func projectParentLabel(_ projectPath: String) -> String {
        let parent = URL(fileURLWithPath: projectPath).deletingLastPathComponent()
        return parent.pathComponents.suffix(2).joined(separator: "/")
    }

    private func expandProjectsWithOpenTerminals() {
        for terminal in store.terminalSessions {
            expandedProjectPaths.insert(terminal.projectDirectoryKey)
        }
    }
}
