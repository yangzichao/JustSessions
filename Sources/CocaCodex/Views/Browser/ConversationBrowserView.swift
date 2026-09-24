import SwiftUI

struct ConversationBrowserView: View {
    @ObservedObject var store: ConversationStore
    @Binding var searchText: String
    @Binding var selection: ConversationBrowserSelection
    @Binding var providerFilter: ConversationProviderFilter
    let onRename: (Conversation) -> Void
    let onDelete: (Conversation) -> Void

    @State private var selectedConversationID: String?
    @State private var isNewSessionSheetPresented = false
    @StateObject private var updateManager = AppUpdateManager()

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
        ProjectConversationGroup.grouped(store.conversations.filter {
            providerFilter.includes($0.provider)
        })
    }

    private var availableProjects: [ProjectConversationGroup] {
        ProjectConversationGroup.grouped(store.conversations)
            .filter { $0.conversations.first?.isProjectAvailable == true }
    }

    private var displayedConversations: [Conversation] {
        switch selection {
        case .all: matchingConversations
        case .recent: matchingConversations.filter { $0.updatedAt >= Date().addingTimeInterval(-7 * 24 * 60 * 60) }
        case .project(let path): matchingConversations.filter { $0.projectDirectoryKey == path }
        }
    }

    var body: some View {
        ResizableSidebarLayout {
            ConversationSidebarView(
                store: store,
                searchText: $searchText,
                selection: selection,
                selectedConversationID: selectedConversationID,
                projects: projectGroups,
                conversationCount: matchingConversations.count,
                recentCount: matchingConversations.filter {
                    $0.updatedAt >= Date().addingTimeInterval(-7 * 24 * 60 * 60)
                }.count,
                isCheckingForUpdates: updateManager.isCheckingForUpdates || updateManager.isInstallingUpdate,
                onCheckForUpdates: { updateManager.checkForUpdates() },
                onNewSession: { isNewSessionSheetPresented = true },
                onSelect: { destination in
                    if case .project = destination { searchText = "" }
                    selection = destination
                    selectedConversationID = nil
                    store.selectTerminal(nil)
                },
                onSelectConversation: { conversation in
                    searchText = ""
                    selection = .project(conversation.projectDirectoryKey)
                    selectedConversationID = conversation.id
                    if let openTerminal = store.terminalSessions.first(where: {
                        $0.conversation?.id == conversation.id && $0.action == .resume && !$0.hasExited
                    }) ?? store.terminalSessions.first(where: {
                        $0.conversation?.id == conversation.id && $0.action == .resume
                    }) {
                        store.selectTerminal(openTerminal.id)
                    } else {
                        store.selectTerminal(nil)
                    }
                }
            )
        } detail: {
            VStack(spacing: 0) {
                WorkspaceTabBar(store: store)
                Divider()
                ZStack {
                    conversationList
                        .opacity(store.selectedTerminalID == nil ? 1 : 0)
                        .allowsHitTesting(store.selectedTerminalID == nil)
                        .accessibilityHidden(store.selectedTerminalID != nil)

                    ForEach(store.terminalSessions) { session in
                        let isActive = store.selectedTerminalID == session.id
                        TerminalWorkspaceView(session: session, isActive: isActive)
                            .opacity(isActive ? 1 : 0)
                            .allowsHitTesting(isActive)
                            .accessibilityHidden(!isActive)
                    }
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                selection = .all
                selectedConversationID = nil
                store.selectTerminal(nil)
            }
        }
        .onChange(of: providerFilter) { _, _ in
            if let selectedConversationID,
               !matchingConversations.contains(where: { $0.id == selectedConversationID }) {
                self.selectedConversationID = nil
            }
            if case .project(let path) = selection,
               !projectGroups.contains(where: { $0.id == path }) {
                selection = .all
                selectedConversationID = nil
            }
        }
        .sheet(isPresented: $isNewSessionSheetPresented) {
            NewSessionSheet(
                initialProvider: newSessionProvider,
                initialProjectPath: newSessionProjectPath,
                recentProjects: availableProjects
            ) { provider, projectPath in
                try store.launchNewSession(provider: provider, projectPath: projectPath)
            }
        }
        .alert(item: $updateManager.notice) { notice in
            if notice.canInstall {
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    primaryButton: .default(Text("Update now")) {
                        updateManager.installUpdate(hasOpenTerminals: {
                            store.terminalSessions.contains { !$0.hasExited }
                        })
                    },
                    secondaryButton: .cancel()
                )
            } else {
                Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            if !updateManager.showPendingResult() {
                updateManager.checkForUpdates(automaticallyInstall: true) {
                    store.terminalSessions.contains { !$0.hasExited }
                }
            }
        }
    }

    private var newSessionProvider: ConversationProvider {
        if let selectedTerminal = store.selectedTerminal { return selectedTerminal.provider }
        switch providerFilter {
        case .claude: return .claude
        case .antigravity: return .antigravity
        case .codex, .all: return .codex
        }
    }

    private var newSessionProjectPath: String {
        if let selectedTerminal = store.selectedTerminal { return selectedTerminal.projectPath }
        if case .project(let path) = selection { return path }
        return availableProjects.first?.projectPath ?? ""
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
                ScrollViewReader { scrollProxy in
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
                    .onAppear { scrollToSelectedConversation(using: scrollProxy) }
                    .onChange(of: selectedConversationID) { _, _ in
                        scrollToSelectedConversation(using: scrollProxy)
                    }
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
                if case .project(let path) = selection,
                   let project = projectGroups.first(where: { $0.id == path }) {
                    ProjectNewSessionMenu(project: project, showsTitle: true) { provider in
                        store.launchNewSessionFromProject(provider: provider, projectPath: project.projectPath)
                    }
                    .buttonStyle(.borderedProminent)
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
        let source = providerFilter == .all ? "All tools" : providerFilter.rawValue
        return "\(count) \(count == 1 ? "session" : "sessions") · \(source)"
    }

    private func projectSection(_ project: ProjectConversationGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    selection = .project(project.id)
                    selectedConversationID = nil
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
                .frame(maxWidth: .infinity)
                .help(project.projectPath)

                ProjectNewSessionMenu(project: project, showsTitle: false) { provider in
                    store.launchNewSessionFromProject(provider: provider, projectPath: project.projectPath)
                }
                .menuStyle(.borderlessButton)
            }
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
            isSelected: selectedConversationID == conversation.id,
            onResume: { store.launch(conversation, action: .resume) },
            onBranch: { store.launch(conversation, action: .branch) },
            onRename: { onRename(conversation) },
            onDelete: { onDelete(conversation) },
            canDelete: !store.hasTerminal(for: conversation) && !store.isLoading && store.deletingConversationID == nil,
            isDeleting: store.deletingConversationID == conversation.id
        )
        .id(conversation.id)
    }

    private func scrollToSelectedConversation(using scrollProxy: ScrollViewProxy) {
        guard let selectedConversationID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo(selectedConversationID, anchor: .center)
            }
        }
    }
}
