import SwiftUI

struct ConversationBrowserView: View {
    @ObservedObject var store: ConversationStore
    @Binding var searchText: String
    @Binding var selection: ConversationBrowserSelection
    @Binding var providerFilter: ConversationProviderFilter
    let onRename: (Conversation) -> Void
    let onDelete: (Conversation) -> Void

    private var matchingConversations: [Conversation] {
        store.conversations.filter { conversation in
            providerFilter.includes(conversation.provider) && (
                searchText.isEmpty || [
                    store.title(for: conversation), conversation.projectPath, conversation.sessionID
                ].contains { $0.localizedCaseInsensitiveContains(searchText) }
            )
        }
    }

    private var projectGroups: [ProjectConversationGroup] {
        ProjectConversationGroup.grouped(matchingConversations)
    }

    private var displayedConversations: [Conversation] {
        switch selection {
        case .all: matchingConversations
        case .recent: matchingConversations.filter { $0.updatedAt >= Date().addingTimeInterval(-7 * 24 * 60 * 60) }
        case .project(let path): matchingConversations.filter { $0.projectDirectoryKey == path }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ConversationSidebarView(
                searchText: $searchText,
                selection: selection,
                projects: projectGroups,
                conversationCount: matchingConversations.count,
                recentCount: matchingConversations.filter {
                    $0.updatedAt >= Date().addingTimeInterval(-7 * 24 * 60 * 60)
                }.count,
                onSelect: { destination in
                    selection = destination
                    store.selectTerminal(nil)
                }
            )
            Divider()
            if let session = store.selectedTerminal {
                TerminalWorkspaceView(store: store, session: session)
            } else {
                conversationList
            }
        }
        .frame(minWidth: 940, minHeight: 550)
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                selection = .all
                store.selectTerminal(nil)
            }
        }
        .onChange(of: providerFilter) { _, _ in
            if case .project(let path) = selection,
               !projectGroups.contains(where: { $0.id == path }) {
                selection = .all
            }
        }
    }

    private var conversationList: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.isLoading && store.conversations.isEmpty {
                ContentUnavailableView("Scanning conversations", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayedConversations.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No conversations here" : "No matching conversations",
                    systemImage: "text.bubble"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if case .project = selection {
                            ForEach(displayedConversations) { conversation in
                                conversationRow(conversation)
                            }
                        } else {
                            ForEach(ProjectConversationGroup.grouped(displayedConversations)) { project in
                                projectSection(project)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                }
                .id(selection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 12) {
                Text(headerTitle)
                    .font(.system(size: 23, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if !store.terminalSessions.isEmpty {
                    Menu {
                        ForEach(store.terminalSessions) { session in
                            Button(session.displayTitle) { store.selectTerminal(session.id) }
                        }
                    } label: {
                        Label("Running \(store.terminalSessions.count)", systemImage: "terminal")
                    }
                    .help("Open an active terminal")
                }
                Picker("Tool", selection: $providerFilter) {
                    ForEach(ConversationProviderFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
                Button { store.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isLoading || store.deletingConversationID != nil)
                .help("Refresh sessions")
                .accessibilityLabel("Refresh sessions")
            }
            Text(headerSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var headerTitle: String {
        if !searchText.isEmpty { return "Search results" }
        switch selection {
        case .all: return "All sessions"
        case .recent: return "Recent"
        case .project(let path): return URL(fileURLWithPath: path).lastPathComponent
        }
    }

    private var headerSubtitle: String {
        if case .project(let path) = selection { return path }
        let count = displayedConversations.count
        let source = providerFilter == .all ? "Claude Code and Codex" : providerFilter.rawValue
        return "\(count) \(count == 1 ? "session" : "sessions") · \(source)"
    }

    private func projectSection(_ project: ProjectConversationGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                selection = .project(project.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(project.projectName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("\(project.conversations.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(project.projectPath)
            .padding(.bottom, 8)

            ForEach(project.conversations) { conversation in
                conversationRow(conversation)
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        ConversationRow(
            conversation: conversation,
            title: store.title(for: conversation),
            onResume: { store.launch(conversation, action: .resume) },
            onBranch: { store.launch(conversation, action: .branch) },
            onRename: { onRename(conversation) },
            onDelete: { onDelete(conversation) },
            canDelete: !store.hasTerminal(for: conversation) && !store.isLoading && store.deletingConversationID == nil,
            isDeleting: store.deletingConversationID == conversation.id
        )
    }
}
