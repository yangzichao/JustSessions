import SwiftUI

private enum ProviderFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case claude = "Claude Code"
    case codex = "Codex"
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var store = ConversationStore()
    @State private var searchText = ""
    @State private var recentOnly = false
    @State private var providerFilter: ProviderFilter = .all
    @State private var renamingConversation: Conversation?
    @State private var editedTitle = ""

    private var filteredConversations: [Conversation] {
        store.conversations.filter { conversation in
            let matchesProvider = providerFilter == .all || conversation.provider.rawValue == providerFilter.rawValue
            let matchesRecency = !recentOnly || conversation.updatedAt >= Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let matchesSearch = searchText.isEmpty || [
                store.title(for: conversation), conversation.projectPath, conversation.sessionID
            ].contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesProvider && matchesRecency && matchesSearch
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if store.isLoading && store.conversations.isEmpty {
                ContentUnavailableView("Scanning conversations", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredConversations.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No conversations found" : "No matching conversations",
                    systemImage: "text.bubble"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(ConversationProvider.allCases) { provider in
                            providerSection(provider)
                        }
                    }
                    .padding(20)
                }
            }

            Divider()
            HStack {
                Text("\(filteredConversations.count) conversations")
                Spacer()
                Text("Names are saved locally. Branch uses the CLI's native fork.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 760, minHeight: 510)
        .onAppear { store.refresh() }
        .alert("Rename conversation", isPresented: Binding(
            get: { renamingConversation != nil },
            set: { if !$0 { renamingConversation = nil } }
        )) {
            TextField("Name", text: $editedTitle)
            Button("Cancel", role: .cancel) { renamingConversation = nil }
            Button("Save") {
                if let conversation = renamingConversation { store.rename(conversation, to: editedTitle) }
                renamingConversation = nil
            }
        } message: {
            Text("This changes the display name in claudex-macos.")
        }
        .alert("Could not complete action", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.dismissError() } }
        )) {
            Button("OK") { store.dismissError() }
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Conversations").font(.largeTitle.bold())
                    Text("Claude Code and Codex sessions, in their native terminal")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: $recentOnly) {
                    Label("Recent", systemImage: "clock")
                }
                .toggleStyle(.button)
                .help("Show sessions active in the past 7 days")
                Button { store.refresh() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
            HStack(spacing: 12) {
                TextField("Search names, projects, or session IDs", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Picker("Provider", selection: $providerFilter) {
                    ForEach(ProviderFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private func providerSection(_ provider: ConversationProvider) -> some View {
        let conversations = filteredConversations.filter { $0.provider == provider }
        if !conversations.isEmpty {
            HStack {
                Image(systemName: provider.symbolName)
                Text(provider.rawValue)
                Text("\(conversations.count)").foregroundStyle(.secondary)
            }
            .font(.title2.bold())

            let projectPaths = Array(Set(conversations.map(\.projectPath))).sorted {
                latestDate(for: $0, in: conversations) > latestDate(for: $1, in: conversations)
            }
            ForEach(projectPaths, id: \.self) { projectPath in
                projectSection(projectPath, conversations: conversations)
            }
        }
    }

    private func projectSection(_ projectPath: String, conversations: [Conversation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(URL(fileURLWithPath: projectPath).lastPathComponent)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.top, 5)
            ForEach(conversations.filter { $0.projectPath == projectPath }) { conversation in
                ConversationRow(
                    conversation: conversation,
                    title: store.title(for: conversation),
                    onResume: { store.launch(conversation, action: .resume) },
                    onBranch: { store.launch(conversation, action: .branch) },
                    onRename: {
                        editedTitle = store.title(for: conversation)
                        renamingConversation = conversation
                    }
                )
            }
        }
    }

    private func latestDate(for projectPath: String, in conversations: [Conversation]) -> Date {
        conversations.first { $0.projectPath == projectPath }?.updatedAt ?? .distantPast
    }
}
