import Combine
import Foundation

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var aliases: [String: String]
    @Published private(set) var terminalSessions: [TerminalSession] = []
    @Published private(set) var selectedTerminalID: UUID?
    @Published private(set) var deletingConversationID: String?
    @Published private(set) var deletingProjectPath: String?

    private let adapters: [any ConversationAdapter]
    private let commandResolver = NativeCLICommandResolver()
    private let aliasesKey = "conversationAliases"

    init(adapters: [any ConversationAdapter] = [ClaudeAdapter(), CodexAdapter(), AntigravityAdapter()]) {
        self.adapters = adapters
        self.aliases = UserDefaults.standard.dictionary(forKey: aliasesKey) as? [String: String] ?? [:]
        startClaudeLiveNameSync()
    }

    func refresh() {
        guard !isLoading && deletingConversationID == nil && deletingProjectPath == nil else { return }
        isLoading = true
        errorMessage = nil
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
                self.associateOpenCodexSessions()
                self.errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
                self.isLoading = false
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
        if conversation.provider == .codex { associateOpenCodexSessions() }
    }

    func hasTerminal(for conversation: Conversation) -> Bool {
        terminalSessions.contains { $0.conversation?.id == conversation.id }
    }

    func deletionPlan(for projectPath: String) -> ProjectSessionDeletionPlan {
        let projectConversations = conversations.filter { $0.projectDirectoryKey == projectPath }
        let openConversations = projectConversations.filter {
            $0.provider.supportsDeletionFromLauncher && hasTerminal(for: $0)
        }
        let unsupportedConversations = projectConversations.filter { !$0.provider.supportsDeletionFromLauncher }
        return ProjectSessionDeletionPlan(
            projectPath: projectPath,
            deletableConversations: projectConversations.filter {
                $0.provider.supportsDeletionFromLauncher && !hasTerminal(for: $0)
            },
            openTerminalCount: openConversations.count,
            unsupportedCount: unsupportedConversations.count
        )
    }

    func delete(_ conversation: Conversation) {
        guard conversation.provider.supportsDeletionFromLauncher else { return }
        guard !hasTerminal(for: conversation) else {
            errorMessage = ConversationDeletionError.activeTerminal.localizedDescription
            return
        }
        guard !isLoading, deletingConversationID == nil, deletingProjectPath == nil,
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
        guard !isLoading, deletingConversationID == nil, deletingProjectPath == nil else { return }
        let deletionPlan = deletionPlan(for: projectPath)
        guard deletionPlan.hasDeletableConversations else { return }

        deletingProjectPath = projectPath
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
                self.deletingProjectPath = nil
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
    }

    func launch(_ conversation: Conversation, action: ConversationAction) {
        guard deletingConversationID != conversation.id,
              deletingProjectPath != conversation.projectDirectoryKey else { return }
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
        let session = TerminalSession(
            conversation: nil,
            provider: provider,
            projectPath: standardizedPath,
            action: .new,
            displayTitle: "New \(provider.rawValue) session",
            command: command
        )
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
