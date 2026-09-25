import Combine
import Foundation

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var aliases: [String: String]
    @Published private(set) var projectDisplayNames: ProjectDisplayNames
    @Published private(set) var pinnedItems: PinnedItems
    @Published private(set) var terminalSessions: [TerminalSession] = []
    @Published private(set) var selectedTerminalID: UUID?
    @Published private(set) var deletingConversationID: String?
    /// Every conversation queued in the running batch deletion.
    @Published private(set) var batchDeletionConversationIDs: Set<String> = []
    private(set) var lastRefreshStartedAt: Date?
    /// A refresh asked for while one runs; that one may have read the files before the change that prompted it.
    private var isRefreshQueued = false

    private let adapters: [any ConversationAdapter]
    private let commandResolver = NativeCLICommandResolver()
    private let aliasesKey = "conversationAliases"

    init(adapters: [any ConversationAdapter] = [ClaudeAdapter(), CodexAdapter(), AntigravityAdapter()]) {
        self.adapters = adapters
        self.aliases = UserDefaults.standard.dictionary(forKey: aliasesKey) as? [String: String] ?? [:]
        self.projectDisplayNames = ProjectDisplayNames.load(from: .standard)
        self.pinnedItems = PinnedItems.load(from: .standard)
        LoginShellPathReader.warmUpInBackground()
        ClaudeSessionIDFlagSupport.shared.warmUpInBackground()
        startClaudeLiveNameSync()
        startNewSessionDiscovery()
    }

    func refresh() {
        guard !isDeletingSessions else { return }
        guard !isLoading else {
            isRefreshQueued = true
            return
        }
        isLoading = true
        errorMessage = nil
        lastRefreshStartedAt = .now
        let adapters = self.adapters
        Task.detached(priority: .userInitiated) {
            var found: [Conversation] = []
            var failures: [String] = []
            for adapter in adapters {
                do { found += try adapter.discover() }
                catch { failures.append("\(adapter.provider.rawValue): \(error.localizedDescription)") }
            }
            found.sort { $0.updatedAt > $1.updatedAt }
            await MainActor.run {
                self.conversations = found
                self.synchronizeTerminalTitles()
                self.errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
                self.isLoading = false
                if self.isRefreshQueued {
                    self.isRefreshQueued = false
                    self.refresh()
                } else {
                    Task { await self.discoverNewSessions(mayRefresh: false) }
                }
            }
        }
    }

    func title(for conversation: Conversation) -> String {
        aliases[conversation.id] ?? conversation.suggestedTitle
    }

    func applySuggestedTitle(_ title: String, toSessionID sessionID: String, provider: ConversationProvider) {
        guard let index = conversations.firstIndex(where: { $0.provider == provider && $0.sessionID == sessionID }),
              conversations[index].suggestedTitle != title else { return }
        conversations[index] = conversations[index].withSuggestedTitle(title)
    }

    func rename(_ conversation: Conversation, to proposedTitle: String) {
        let title = proposedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty || title == conversation.suggestedTitle {
            aliases.removeValue(forKey: conversation.id)
        } else {
            aliases[conversation.id] = title
        }
        UserDefaults.standard.set(aliases, forKey: aliasesKey)
        synchronizeTerminalTitles()
    }

    func projectDisplayName(forProjectPath projectPath: String) -> String {
        projectDisplayNames.displayName(forProjectPath: projectPath)
    }

    func renameProject(_ projectPath: String, to proposedName: String) {
        projectDisplayNames.rename(projectPath: projectPath, to: proposedName)
        projectDisplayNames.save(to: .standard)
    }

    func setPinned(_ isPinned: Bool, projectPath: String) {
        pinnedItems.setPinned(isPinned, projectPath: projectPath)
        pinnedItems.save(to: .standard)
    }

    func setPinned(_ isPinned: Bool, conversation: Conversation) {
        pinnedItems.setPinned(isPinned, conversationID: conversation.id)
        pinnedItems.save(to: .standard)
    }

    func hasTerminal(for conversation: Conversation) -> Bool {
        terminalSessions.contains { $0.conversation?.id == conversation.id }
    }

    var isDeletingSessions: Bool {
        deletingConversationID != nil || !batchDeletionConversationIDs.isEmpty
    }

    func isDeletionPending(for conversation: Conversation) -> Bool {
        deletingConversationID == conversation.id || batchDeletionConversationIDs.contains(conversation.id)
    }

    func deletionPlan(for projectPath: String) -> SessionDeletionPlan {
        deletionPlan(for: conversations.filter { $0.projectDirectoryKey == projectPath })
    }

    func deletionPlan(for candidateConversations: [Conversation]) -> SessionDeletionPlan {
        let supportedConversations = candidateConversations.filter { $0.provider.supportsDeletionFromLauncher }
        return SessionDeletionPlan(
            deletableConversations: supportedConversations.filter { !hasTerminal(for: $0) },
            openTerminalCount: supportedConversations.filter { hasTerminal(for: $0) }.count,
            unsupportedCount: candidateConversations.count - supportedConversations.count
        )
    }

    func delete(_ conversation: Conversation) {
        guard conversation.provider.supportsDeletionFromLauncher else { return }
        guard !hasTerminal(for: conversation) else {
            errorMessage = ConversationDeletionError.activeTerminal.localizedDescription
            return
        }
        guard !isLoading, !isDeletingSessions,
              let adapter = adapters.first(where: { $0.provider == conversation.provider }) else { return }
        deletingConversationID = conversation.id
        Task.detached(priority: .userInitiated) {
            do {
                try adapter.delete(conversation)
                await MainActor.run {
                    self.removeDeletedConversation(conversation)
                    self.deletingConversationID = nil
                }
            } catch {
                await MainActor.run {
                    if !FileManager.default.fileExists(atPath: conversation.sourceFile.path) {
                        self.removeDeletedConversation(conversation)
                    }
                    self.errorMessage = error.localizedDescription
                    self.deletingConversationID = nil
                }
            }
        }
    }

    func deleteSessions(in projectPath: String) {
        deleteConversations(conversations.filter { $0.projectDirectoryKey == projectPath })
    }

    /// Deletes every deletable conversation in the list; open terminals and unsupported providers are skipped.
    func deleteConversations(_ candidateConversations: [Conversation]) {
        guard !isLoading, !isDeletingSessions else { return }
        let candidateIDs = Set(candidateConversations.map(\.id))
        let deletionPlan = deletionPlan(for: conversations.filter { candidateIDs.contains($0.id) })
        guard deletionPlan.hasDeletableConversations else { return }

        batchDeletionConversationIDs = Set(deletionPlan.deletableConversations.map(\.id))
        let adapters = self.adapters
        Task.detached(priority: .userInitiated) {
            var failures: [String] = []
            for conversation in deletionPlan.deletableConversations {
                guard let adapter = adapters.first(where: { $0.provider == conversation.provider }) else { continue }
                await MainActor.run { self.deletingConversationID = conversation.id }
                do {
                    try adapter.delete(conversation)
                    await MainActor.run { self.removeDeletedConversation(conversation) }
                } catch {
                    await MainActor.run {
                        if !FileManager.default.fileExists(atPath: conversation.sourceFile.path) {
                            self.removeDeletedConversation(conversation)
                        }
                    }
                    failures.append("\(conversation.provider.rawValue) · \(conversation.suggestedTitle): \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                self.deletingConversationID = nil
                self.batchDeletionConversationIDs = []
                if !failures.isEmpty {
                    self.errorMessage = "Some sessions could not be deleted:\n" + failures.joined(separator: "\n")
                }
            }
        }
    }

    private func removeDeletedConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        aliases.removeValue(forKey: conversation.id)
        UserDefaults.standard.set(aliases, forKey: aliasesKey)
        if pinnedItems.isPinned(conversationID: conversation.id) {
            setPinned(false, conversation: conversation)
        }
    }

    func canLaunch(_ conversation: Conversation, action: ConversationAction) -> Bool {
        conversation.isProjectAvailable && !isDeletionPending(for: conversation)
            && (action != .branch || conversation.provider.supportsBranchFromLauncher)
    }

    /// Opens one terminal tab per launchable conversation, in list order; the last one ends up selected.
    func launch(_ conversations: [Conversation], action: ConversationAction) {
        for conversation in conversations where canLaunch(conversation, action: action) {
            launch(conversation, action: action)
        }
    }

    func launch(_ conversation: Conversation, action: ConversationAction) {
        guard !isDeletionPending(for: conversation) else { return }
        guard action != .branch || conversation.provider.supportsBranchFromLauncher else { return }
        if action == .resume,
           let runningSession = terminalSessions.first(where: {
               $0.conversation?.id == conversation.id && !$0.hasExited
           }) {
            selectedTerminalID = runningSession.id
            return
        }
        guard let adapter = adapters.first(where: { $0.provider == conversation.provider }) else { return }
        do {
            let command = try commandResolver.resolve(conversation: conversation, action: action, adapter: adapter)
            let session = TerminalSession(
                conversation: conversation,
                provider: conversation.provider,
                projectPath: conversation.projectPath,
                action: action,
                displayTitle: title(for: conversation),
                command: command
            )
            terminalSessions.append(session)
            selectedTerminalID = session.id
        }
        catch { errorMessage = error.localizedDescription }
    }

    func launchNewSession(provider: ConversationProvider, projectPath: String) throws {
        let expandedPath = (projectPath as NSString).expandingTildeInPath
        let standardizedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path
        let command = try commandResolver.resolveNewSession(provider: provider, projectPath: standardizedPath)
        let preassignment = provider == .claude
            ? ClaudeSessionIDFlagSupport.shared.preassigningSessionID(to: command)
            : nil
        let session = TerminalSession(
            conversation: nil,
            provider: provider,
            projectPath: standardizedPath,
            action: .new,
            displayTitle: "New \(provider.rawValue) session",
            command: preassignment?.command ?? command,
            preassignedSessionID: preassignment?.sessionID
        )
        // A CLI that exits on its own leaves its tab open; list what it saved without waiting for the tab to close.
        session.onProcessFinished = { [weak self] in self?.refresh() }
        terminalSessions.append(session)
        selectedTerminalID = session.id
    }

    func launchNewSessionFromProject(provider: ConversationProvider, projectPath: String) {
        do {
            try launchNewSession(provider: provider, projectPath: projectPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var selectedTerminal: TerminalSession? {
        terminalSessions.first { $0.id == selectedTerminalID }
    }

    func selectTerminal(_ id: UUID?) {
        let shouldRefreshNewSession = selectedTerminal?.action == .new && selectedTerminalID != id
        selectedTerminalID = id
        if shouldRefreshNewSession { refresh() }
    }

    func closeTerminal(_ id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        let shouldRefreshNewSession = terminalSessions[index].action == .new
        terminalSessions[index].close()
        terminalSessions.remove(at: index)
        if selectedTerminalID == id { selectedTerminalID = terminalSessions.last?.id }
        if shouldRefreshNewSession { refresh() }
    }

    func closeAllTerminals() {
        for session in terminalSessions { session.close() }
        terminalSessions = []
        selectedTerminalID = nil
    }

    func dismissError() {
        errorMessage = nil
    }
}
