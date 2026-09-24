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
        let visibleConversations = filteredConversations
        let projectGroups = ProjectConversationGroup.grouped(visibleConversations)
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if store.isLoading && store.conversations.isEmpty {
                ContentUnavailableView("Scanning conversations", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleConversations.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No conversations found" : "No matching conversations",
                    systemImage: "text.bubble"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(projectGroups) { projectGroup in
                            projectSection(projectGroup)
                        }
                    }
                    .padding(20)
                }
            }

            Divider()
            HStack {
                Text("\(projectGroups.count) projects · \(visibleConversations.count) conversations")
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
                    Text("Sessions from Claude Code and Codex, grouped by project folder")
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

    private func projectSection(_ group: ProjectConversationGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                Text(group.projectName).font(.title3.bold())
                Text("\(group.conversations.count)").foregroundStyle(.secondary)
            }
            Text(group.projectPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            ForEach(group.conversations) { conversation in
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
}
