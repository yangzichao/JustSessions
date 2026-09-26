import Combine
import Foundation

/// The listed sessions and open tabs. State changes here; the `ConversationStore+…` extensions build on the
/// methods below to refresh hosts, launch CLIs, and link new sessions to their tabs.
@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var titleAliases: ConversationTitleAliases
    @Published private(set) var projectDisplayNames: ProjectDisplayNames
    @Published private(set) var pinnedItems: PinnedItems
    @Published private(set) var terminalSessions: [TerminalSession] = []
    @Published private(set) var selectedTerminalID: UUID?
    @Published private(set) var deletingConversationID: String?
    /// Every conversation queued in the running batch deletion.
    @Published private(set) var batchDeletionConversationIDs: Set<String> = []
    /// The SSH hosts listed after this Mac.
    @Published var remoteHostList: RemoteHostList
    /// Each host's last refresh, this Mac's included.
    @Published var hostRefreshStatuses: [SessionHost: HostRefreshStatus] = [:]
    /// tmux sessions JustSessions started that still run, per host, as of the host's last refresh.
    @Published var tmuxSessionNamesByHost: [SessionHost: Set<String>] = [:]
    private(set) var lastRefreshStartedAt: Date?
    /// A refresh asked for while one runs; that one may have read the files before the change that prompted it.
    private var isRefreshQueued = false

    private let adapters: [any ConversationAdapter]
    let commandResolver: NativeCLICommandResolver
    /// Where custom titles, project names, pins, and SSH hosts are kept.
    let userDefaults: UserDefaults

    init(
        adapters: [any ConversationAdapter] = [ClaudeAdapter(), CodexAdapter(), AntigravityAdapter()],
        commandResolver: NativeCLICommandResolver = NativeCLICommandResolver(),
        userDefaults: UserDefaults = .standard
    ) {
        self.adapters = adapters
        self.commandResolver = commandResolver
        self.userDefaults = userDefaults
        self.titleAliases = ConversationTitleAliases.load(from: userDefaults)
        self.projectDisplayNames = ProjectDisplayNames.load(from: userDefaults)
        self.pinnedItems = PinnedItems.load(from: userDefaults)
        self.remoteHostList = RemoteHostList.load(from: userDefaults)
        LoginShellPathReader.warmUpInBackground()
        ClaudeSessionIDFlagSupport.shared.warmUpInBackground()
        startClaudeLiveNameSync()
        startNewSessionDiscovery()
        startRemoteNewSessionPolling()
        startTmuxPaneProcessLookup()
    }

    /// Scans the session folders on this Mac. SSH hosts refresh on their own, so a slow host never holds this up.
    func refreshThisMac() {
        guard !isDeletingSessions else { return }
        guard !isScanningThisMac else {
            isRefreshQueued = true
            return
        }
        hostRefreshStatuses[.thisMac] = .refreshing
        lastRefreshStartedAt = .now
        let adapters = self.adapters
        let installedTmux = commandResolver.installedTmuxServer()
        Task.detached(priority: .userInitiated) {
            var found: [Conversation] = []
            var failures: [String] = []
            for adapter in adapters {
                do { found += try adapter.discover() }
                catch { failures.append("\(adapter.provider.rawValue): \(error.localizedDescription)") }
            }
            // The first refresh also checks the tmux version, so tabs can run in tmux from then on.
            let tmuxSessionNames = installedTmux.map { $0.hasSupportedVersion() ? $0.sessionNames() : [] } ?? []
            await MainActor.run {
                self.tmuxSessionNamesByHost[.thisMac] = tmuxSessionNames
                self.replaceConversations(on: .thisMac, with: found)
                self.hostRefreshStatuses[.thisMac] = failures.isEmpty
                    ? .refreshed(.now)
                    : .failed(failures.joined(separator: "\n"))
                if self.isRefreshQueued {
                    self.isRefreshQueued = false
                    self.refreshThisMac()
                } else {
                    Task { await self.discoverNewSessions(mayRefresh: false) }
                }
            }
        }
    }

    /// Swaps in what one host lists now, keeping every other host's sessions.
    func replaceConversations(on host: SessionHost, with hostConversations: [Conversation]) {
        conversations = (conversations.filter { $0.host != host } + hostConversations)
            .sorted { $0.updatedAt > $1.updatedAt }
        synchronizeTerminalTitles()
    }

    func adapter(for provider: ConversationProvider) -> (any ConversationAdapter)? {
        adapters.first { $0.provider == provider }
    }

    // MARK: - Titles, project names, and pins

    func title(for conversation: Conversation) -> String {
        titleAliases.title(for: conversation)
    }

    func applySuggestedTitle(_ title: String, toSessionID sessionID: String, provider: ConversationProvider) {
        guard let index = conversations.firstIndex(where: { $0.provider == provider && $0.sessionID == sessionID }),
              conversations[index].suggestedTitle != title else { return }
        conversations[index] = conversations[index].withSuggestedTitle(title)
    }

    func rename(_ conversation: Conversation, to proposedTitle: String) {
        titleAliases.rename(conversation, to: proposedTitle)
        titleAliases.save(to: userDefaults)
        synchronizeTerminalTitles()
    }

    func projectDisplayName(forProjectPath projectPath: String) -> String {
        projectDisplayNames.displayName(forProjectPath: projectPath)
    }

    func renameProject(_ projectPath: String, to proposedName: String) {
        projectDisplayNames.rename(projectPath: projectPath, to: proposedName)
        projectDisplayNames.save(to: userDefaults)
    }

    func setPinned(_ isPinned: Bool, projectPath: String) {
        pinnedItems.setPinned(isPinned, projectPath: projectPath)
        pinnedItems.save(to: userDefaults)
    }

    func setPinned(_ isPinned: Bool, conversation: Conversation) {
        pinnedItems.setPinned(isPinned, conversationID: conversation.id)
        pinnedItems.save(to: userDefaults)
    }

    // MARK: - Deletion

    /// A tab in this window, or a CLI still running in tmux on the session's host.
    func hasTerminal(for conversation: Conversation) -> Bool {
        terminalSessions.contains { $0.conversation?.id == conversation.id } || isRunningInTmux(conversation)
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
        let supportedConversations = candidateConversations.filter(\.supportsDeletionFromLauncher)
        return SessionDeletionPlan(
            deletableConversations: supportedConversations.filter { !hasTerminal(for: $0) },
            openTerminalCount: supportedConversations.filter { hasTerminal(for: $0) }.count,
            unsupportedCount: candidateConversations.count - supportedConversations.count
        )
    }

    func delete(_ conversation: Conversation) {
        guard conversation.supportsDeletionFromLauncher else { return }
        guard !hasTerminal(for: conversation) else {
            errorMessage = ConversationDeletionError.activeTerminal.localizedDescription
            return
        }
        guard !isScanningThisMac, !isDeletingSessions, adapter(for: conversation.provider) != nil else { return }
        deletingConversationID = conversation.id
        deleteInBackground([conversation], failureMessage: ConversationDeletionFailure.messageAfterDeletingOneSession)
    }

    func deleteSessions(in projectPath: String) {
        deleteConversations(conversations.filter { $0.projectDirectoryKey == projectPath })
    }

    /// Deletes every deletable conversation in the list; open terminals and unsupported providers are skipped.
    func deleteConversations(_ candidateConversations: [Conversation]) {
        guard !isScanningThisMac, !isDeletingSessions else { return }
        let candidateIDs = Set(candidateConversations.map(\.id))
        let deletionPlan = deletionPlan(for: conversations.filter { candidateIDs.contains($0.id) })
        guard deletionPlan.hasDeletableConversations else { return }

        batchDeletionConversationIDs = Set(deletionPlan.deletableConversations.map(\.id))
        deleteInBackground(
            deletionPlan.deletableConversations,
            failureMessage: ConversationDeletionFailure.messageAfterDeletingSeveralSessions
        )
    }

    /// Deletes the conversations one at a time off the main actor, then shows `failureMessage` for any that failed.
    /// A conversation whose file is gone leaves the list even when its deletion reported an error.
    private func deleteInBackground(
        _ deletableConversations: [Conversation],
        failureMessage: @escaping @Sendable ([ConversationDeletionFailure]) -> String
    ) {
        let adapters = self.adapters
        Task.detached(priority: .userInitiated) {
            var failures: [ConversationDeletionFailure] = []
            for conversation in deletableConversations {
                guard let adapter = adapters.first(where: { $0.provider == conversation.provider }) else { continue }
                await MainActor.run { self.deletingConversationID = conversation.id }
                do {
                    try Self.deleteFromDisk(conversation, adapter: adapter)
                    await MainActor.run { self.removeDeletedConversation(conversation) }
                } catch {
                    failures.append(ConversationDeletionFailure(conversation: conversation, reason: error.localizedDescription))
                    await MainActor.run {
                        if !FileManager.default.fileExists(atPath: conversation.sourceFile.path) {
                            self.removeDeletedConversation(conversation)
                        }
                    }
                }
            }
            let finalFailures = failures
            await MainActor.run {
                self.deletingConversationID = nil
                self.batchDeletionConversationIDs = []
                if !finalFailures.isEmpty { self.errorMessage = failureMessage(finalFailures) }
            }
        }
    }

    /// A session on this Mac is deleted by its tool's adapter; one on an SSH host over SSH.
    nonisolated private static func deleteFromDisk(_ conversation: Conversation, adapter: any ConversationAdapter) throws {
        switch conversation.host {
        case .thisMac: try adapter.delete(conversation)
        case .ssh: try RemoteConversationDeletion().delete(conversation)
        }
    }

    private func removeDeletedConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        titleAliases.removeTitle(forConversationID: conversation.id)
        titleAliases.save(to: userDefaults)
        if pinnedItems.isPinned(conversationID: conversation.id) {
            setPinned(false, conversation: conversation)
        }
    }

    // MARK: - Tabs

    /// Swaps a tab for another in the same place, closing the old one; keeps it selected if it was.
    func replaceTerminal(at index: Int, with session: TerminalSession) {
        let replacedID = terminalSessions[index].id
        terminalSessions[index].close()
        terminalSessions[index] = session
        if selectedTerminalID == replacedID { selectedTerminalID = session.id }
    }

    /// Adds the tab and shows it.
    func openTerminal(_ session: TerminalSession) {
        terminalSessions.append(session)
        selectedTerminalID = session.id
    }

    var selectedTerminal: TerminalSession? {
        terminalSessions.first { $0.id == selectedTerminalID }
    }

    /// Leaving a new session's tab refreshes its host, so what its CLI saved so far is listed.
    func selectTerminal(_ id: UUID?) {
        let leftNewSessionTab = selectedTerminalID == id ? nil : selectedTerminal.flatMap { $0.action.startsNewSession ? $0 : nil }
        selectedTerminalID = id
        if let leftNewSessionTab { refresh(leftNewSessionTab.host) }
    }

    func closeTerminal(_ id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        let closedTab = terminalSessions[index]
        closedTab.close()
        terminalSessions.remove(at: index)
        if selectedTerminalID == id { selectedTerminalID = terminalSessions.last?.id }
        if closedTab.action.startsNewSession { refresh(closedTab.host) }
    }

    func closeAllTerminals() {
        for session in terminalSessions { session.close() }
        terminalSessions = []
        selectedTerminalID = nil
    }

    // MARK: - Errors

    func showError(_ message: String) {
        errorMessage = message
    }

    func dismissError() {
        errorMessage = nil
    }
}
