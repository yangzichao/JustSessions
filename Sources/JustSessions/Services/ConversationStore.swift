import Combine
import Foundation

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var aliases: [String: String]
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
    private let aliasesKey = "conversationAliases"

    init(
        adapters: [any ConversationAdapter] = [ClaudeAdapter(), CodexAdapter(), AntigravityAdapter()],
        commandResolver: NativeCLICommandResolver = NativeCLICommandResolver()
    ) {
        self.adapters = adapters
        self.commandResolver = commandResolver
        self.aliases = UserDefaults.standard.dictionary(forKey: aliasesKey) as? [String: String] ?? [:]
        self.projectDisplayNames = ProjectDisplayNames.load(from: .standard)
        self.pinnedItems = PinnedItems.load(from: .standard)
        self.remoteHostList = RemoteHostList.load(from: .standard)
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
        guard !isScanningThisMac, !isDeletingSessions,
              let adapter = adapters.first(where: { $0.provider == conversation.provider }) else { return }
        deletingConversationID = conversation.id
        Task.detached(priority: .userInitiated) {
            do {
                try Self.deleteFromDisk(conversation, adapter: adapter)
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
        guard !isScanningThisMac, !isDeletingSessions else { return }
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
                    try Self.deleteFromDisk(conversation, adapter: adapter)
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

    /// A session on this Mac is deleted by its tool's adapter; one on an SSH host over SSH.
    nonisolated private static func deleteFromDisk(_ conversation: Conversation, adapter: any ConversationAdapter) throws {
        switch conversation.host {
        case .thisMac: try adapter.delete(conversation)
        case .ssh: try RemoteConversationDeletion().delete(conversation)
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
        guard let adapter = adapter(for: conversation.provider) else { return }
        do {
            let (command, tmuxSessionName) = try launchCommand(for: conversation, action: action, adapter: adapter)
            // A branch runs a fork with a session id of its own, so its tab waits for that session like a
            // new session's tab does; see new session discovery.
            let isBranch = action == .branch
            let session = TerminalSession(
                conversation: isBranch ? nil : conversation,
                provider: conversation.provider,
                projectPath: conversation.projectPath,
                action: action,
                displayTitle: title(for: conversation),
                command: command,
                branchedFromSessionID: isBranch ? conversation.sessionID : nil,
                host: conversation.host,
                sessionIDsKnownAtLaunch: isBranch ? sessionIDsListed(on: conversation.host) : [],
                tmuxSessionName: tmuxSessionName
            )
            // A CLI that exits on its own leaves its tab open; list what it saved without waiting for the tab to close.
            session.onProcessFinished = { [weak self] in self?.refresh(conversation.host) }
            terminalSessions.append(session)
            selectedTerminalID = session.id
        }
        catch { errorMessage = error.localizedDescription }
    }

    /// On this Mac, the CLI itself, in tmux when it is installed; on an SSH host, `ssh` into the tmux session the
    /// CLI runs in. Also returns the name of the tmux session, if any.
    private func launchCommand(
        for conversation: Conversation,
        action: ConversationAction,
        adapter: any ConversationAdapter
    ) throws -> (command: NativeCLICommand, tmuxSessionName: String?) {
        let tmuxSessionName = tmuxSessionName(forLaunching: conversation, action: action)
        switch conversation.host {
        case .thisMac:
            let command = try commandResolver.resolve(conversation: conversation, action: action, adapter: adapter)
            return thisMacTabCommand(running: command, tmuxSessionName: tmuxSessionName)
        case .ssh(let destination):
            let command = RemoteCLICommandBuilder().command(
                host: destination,
                provider: conversation.provider,
                projectPath: conversation.projectPath,
                arguments: adapter.arguments(for: conversation, action: action),
                tmuxSessionName: tmuxSessionName
            )
            return (command, tmuxSessionName)
        }
    }

    /// Opens a tab running a new session of the tool in the folder, on the folder's host.
    func launchNewSession(provider: ConversationProvider, in location: ProjectLocation) throws {
        switch location.host {
        case .thisMac:
            try launchNewSessionOnThisMac(provider: provider, projectPath: location.path)
        case .ssh(let destination):
            launchNewRemoteSession(provider: provider, host: destination, projectPath: location.path)
        }
    }

    /// From a project's + menu; `projectPath` is the project's key.
    func launchNewSessionFromProject(provider: ConversationProvider, projectPath: String) {
        do {
            try launchNewSession(provider: provider, in: ProjectLocation(key: projectPath))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func launchNewSessionOnThisMac(provider: ConversationProvider, projectPath: String) throws {
        let expandedPath = (projectPath as NSString).expandingTildeInPath
        let standardizedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path
        let command = try commandResolver.resolveNewSession(provider: provider, projectPath: standardizedPath)
        // Before tmux wraps the command: the flag check looks at the CLI's own executable.
        let preassignment = provider == .claude
            ? ClaudeSessionIDFlagSupport.shared.preassigningSessionID(to: command)
            : nil
        // A session whose id is known up front gets its own tmux name right away.
        let tabCommand = thisMacTabCommand(
            running: preassignment?.command ?? command,
            tmuxSessionName: preassignment.map { TmuxSessionName.forSession(provider: provider, sessionID: $0.sessionID) }
                ?? TmuxSessionName.unique(for: provider)
        )
        let session = TerminalSession(
            conversation: nil,
            provider: provider,
            projectPath: standardizedPath,
            action: .new,
            displayTitle: "New \(provider.rawValue) session",
            command: tabCommand.command,
            preassignedSessionID: preassignment?.sessionID,
            tmuxSessionName: tabCommand.tmuxSessionName
        )
        // A CLI that exits on its own leaves its tab open; list what it saved without waiting for the tab to close.
        session.onProcessFinished = { [weak self] in self?.refreshThisMac() }
        terminalSessions.append(session)
        selectedTerminalID = session.id
    }

    func adapter(for provider: ConversationProvider) -> (any ConversationAdapter)? {
        adapters.first { $0.provider == provider }
    }

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

    func dismissError() {
        errorMessage = nil
    }
}
