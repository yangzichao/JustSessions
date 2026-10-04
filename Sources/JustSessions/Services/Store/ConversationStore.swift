import Combine
import Foundation

/// The listed sessions and open tabs. State changes here; the `ConversationStore+…` extensions build on the
/// methods below to refresh hosts, launch CLIs, and link new sessions to their tabs.
@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = [] {
        didSet {
            conversationIndex = ConversationIndex(conversations)
            conversationsRevision &+= 1
        }
    }
    private(set) var conversationIndex = ConversationIndex([])
    /// Changes with every change to `conversations`, so what is worked out from them knows when to work it out again.
    private(set) var conversationsRevision = 0
    /// What the sidebar lists, kept until what it was worked out from changes; see `ConversationStore+SidebarProjects`.
    var cachedSidebarProjection: SidebarProjection?
    /// What the browser last showed for its filters, kept the same way; see `ConversationStore+SidebarProjects`.
    var cachedFilteredSidebarProjection: FilteredSidebarProjection?
    /// What the main window's alert shows, if anything.
    @Published private(set) var alert: StoreAlert?
    /// Alerts that came while `alert` was shown. Each is shown once the ones before it are dismissed, since
    /// SwiftUI keeps showing an alert whose content changes under it.
    private var waitingAlerts: [StoreAlert] = []
    @Published private(set) var titleAliases: ConversationTitleAliases
    @Published private(set) var projectDisplayNames: ProjectDisplayNames
    @Published private(set) var pinnedItems: PinnedItems
    @Published var sidebarProjectList: SidebarProjectList
    @Published private(set) var terminalSessions: [TerminalSession] = []
    /// Selecting a tab that waited to be shown starts it; see `TerminalSession.isWaitingToBeShown`.
    @Published private(set) var selectedTerminalID: UUID? {
        didSet { selectedTerminal?.startNowThatItIsShown() }
    }
    /// Two tabs linked side by side, as in Chrome's split view, or nil with no split made. The pair outlives
    /// the selection; both terminals show only while one of them is selected, see `shownSplitPair`.
    @Published private(set) var terminalSplitPair: TerminalSplitPair?
    /// Every conversation queued in the running deletion, of one session or several. It changes only when a
    /// deletion starts and ends; `deletionProgress` follows the sessions in between.
    @Published private(set) var pendingDeletionConversationIDs: Set<String> = []
    /// How far the running deletion has got. Only the sidebar's progress bar observes it.
    let deletionProgress = SessionDeletionProgress()
    /// The SSH hosts listed after this Mac.
    @Published var remoteHostList: RemoteHostList
    /// Each host's last refresh, this Mac's included.
    @Published var hostRefreshStatuses: [SessionHost: HostRefreshStatus] = [:]
    /// tmux sessions JustSessions started that still run, per host, as of the host's last refresh. On this Mac, one
    /// whose CLI ends leaves within about a second; see `ConversationStore+CLIActivitySync`.
    @Published var tmuxSessionNamesByHost: [SessionHost: Set<String>] = [:]
    /// The tools whose CLI each host has, as of the host's last refresh; a host not checked yet is missing.
    /// See `ConversationStore+InstalledCLIs`.
    @Published var installedProvidersByHost: [SessionHost: Set<ConversationProvider>] = [:]
    /// What the CLI of each session running in tmux on this Mac with no tab open is doing, by conversation id.
    /// A tab's own CLI is on the tab; see `TerminalSession.cliActivity`.
    @Published var detachedCLIActivities: [String: CLIActivity] = [:]
    /// The CLI of each tmux session on this Mac, by session name, as of the last refresh or the closing of its tab.
    var thisMacTmuxPaneProcessIDs: [String: Int32] = [:]
    /// Renames and kills of tmux sessions, in order per host; see `ConversationStore+Tmux`.
    let tmuxCommandQueues = TmuxCommandQueues()
    let codexTurnTracker = CodexRolloutTurnTracker()
    /// What each CLI on this Mac did at the last activity sync; see `ConversationStore+SessionNotifications`.
    var sessionAttentionTracker = SessionAttentionTracker()
    /// Tabs from the last quit still waiting for their host's sessions; see `ConversationStore+TabReopening`.
    var pendingTabReopening = PendingTabReopening()
    let tabPersistenceWindowID = UUID()
    var openTabPersistence: OpenTabPersistence?
    var isRestoringTabBatch = false
    var isTearingDownWorkspace = false
    let sessionNotifier: any SessionNotifying
    private(set) var lastRefreshStartedAt: Date?
    /// A refresh asked for while one runs; that one may have read the files before the change that prompted it.
    private var isRefreshQueued = false
    /// The hosts the running deletion deletes from. A refresh of one waits until it ends, see `deferRefreshWhileDeleting(on:)`.
    private var hostsWithRunningDeletion: Set<SessionHost> = []
    private var hostsToRefreshAfterDeletion: Set<SessionHost> = []
    /// Sessions Try Again asked to delete while a deletion ran or a host they are on was refreshing. They are
    /// deleted when that ends; see `retryDeletion(of:)`.
    private(set) var queuedRetryConversationIDs: Set<String> = []
    private var deletionTask: Task<Void, Never>?
    /// Deleted sessions leave the list, and the progress bar moves, at most this often while a deletion runs, and
    /// once more when it ends. Tests set it to zero to follow each session.
    var deletionListUpdateInterval: Duration = .milliseconds(500)

    private let adapters: [any ConversationAdapter]
    let commandResolver: NativeCLICommandResolver
    /// Deletes sessions on SSH hosts.
    private let remoteDeletion: RemoteConversationDeletion
    /// Where custom titles, project names, pins, sidebar projects, and SSH hosts are kept.
    let userDefaults: UserDefaults

    init(
        adapters: [any ConversationAdapter] = [
            ClaudeAdapter(), CodexAdapter(), AntigravityAdapter(), KiroAdapter(), OpenCodeAdapter(), PiAdapter(),
        ],
        commandResolver: NativeCLICommandResolver = NativeCLICommandResolver(),
        userDefaults: UserDefaults = .standard,
        sessionNotifier: any SessionNotifying = SessionNotificationCenter.shared,
        remoteDeletion: RemoteConversationDeletion = RemoteConversationDeletion(),
        startsBackgroundPolling: Bool = true
    ) {
        self.adapters = adapters
        self.commandResolver = commandResolver
        self.remoteDeletion = remoteDeletion
        self.userDefaults = userDefaults
        self.sessionNotifier = sessionNotifier
        self.titleAliases = ConversationTitleAliases.load(from: userDefaults)
        self.projectDisplayNames = ProjectDisplayNames.load(from: userDefaults)
        self.pinnedItems = PinnedItems.load(from: userDefaults)
        self.sidebarProjectList = SidebarProjectList.load(from: userDefaults)
        self.remoteHostList = RemoteHostList.load(from: userDefaults)
        LoginShellPathReader.warmUpInBackground()
        ClaudeSessionIDFlagSupport.shared.warmUpInBackground()
        if startsBackgroundPolling {
            startClaudeLiveNameSync()
            startNewSessionDiscovery()
            startRemoteNewSessionPolling()
            startTmuxPaneProcessLookup()
            startCLIActivitySync()
        }
        sessionNotifier.follow(self)
    }

    /// Scans the session folders on this Mac. SSH hosts refresh on their own, so a slow host never holds this up.
    func refreshThisMac() {
        guard !deferRefreshWhileDeleting(on: .thisMac) else { return }
        guard !isScanningThisMac else {
            isRefreshQueued = true
            return
        }
        hostRefreshStatuses[.thisMac] = .refreshing
        lastRefreshStartedAt = .now
        let adapters = self.adapters
        let commandResolver = self.commandResolver
        Task.detached(priority: .userInitiated) {
            var found: [Conversation] = []
            var failures: [String] = []
            for adapter in adapters {
                do { found += try adapter.discover() }
                catch { failures.append("\(adapter.provider.rawValue): \(error.localizedDescription)") }
            }
            let installedProviders = InstalledCLIs.onThisMac(commandResolver: commandResolver)
            // The first refresh also checks the tmux version, so tabs can run in tmux from then on.
            let tmuxPaneProcessIDs = commandResolver.refreshThisMacTmuxServer()?.appSessionPaneProcessIDs() ?? [:]
            await MainActor.run {
                self.tmuxSessionNamesByHost[.thisMac] = Set(tmuxPaneProcessIDs.keys)
                self.thisMacTmuxPaneProcessIDs = tmuxPaneProcessIDs
                self.setInstalledProviders(installedProviders, on: .thisMac)
                self.replaceConversations(on: .thisMac, with: found, discardMissingReopeningTabs: failures.isEmpty)
                self.linkWaitingTabsByAppearance(on: .thisMac)
                self.hostRefreshStatuses[.thisMac] = failures.isEmpty
                    ? .refreshed(.now)
                    : .failed(failures.joined(separator: "\n"))
                if self.isRefreshQueued {
                    self.isRefreshQueued = false
                    self.refreshThisMac()
                } else {
                    Task { await self.discoverNewSessions(mayRefresh: false) }
                }
                self.startQueuedRetry()
            }
        }
    }

    /// Swaps in what one host lists now, keeping every other host's sessions.
    func replaceConversations(on host: SessionHost, with hostConversations: [Conversation], discardMissingReopeningTabs: Bool = true) {
        rememberSidebarProjects(Set(hostConversations.map(\.projectDirectoryKey)))
        let updatedConversations = (conversations.filter { $0.host != host } + hostConversations)
            .sorted { $0.updatedAt > $1.updatedAt }
        if conversations != updatedConversations { conversations = updatedConversations }
        synchronizeTerminalTitles()
        reopenWaitingTabs(on: host, discardMissingSessions: discardMissingReopeningTabs)
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
        !pendingDeletionConversationIDs.isEmpty
    }

    /// A deletion waits for the deletion already running, and for the refresh of any host it deletes from: that
    /// refresh may have read a session before it was deleted and would list it again.
    func canStartDeletion(of candidateConversations: [Conversation]) -> Bool {
        !isDeletingSessions && !candidateConversations.contains { hostRefreshStatuses[$0.host] == .refreshing }
    }

    /// Returns true when a deletion runs on `host`; its refresh then starts once the deletion ends, for the same reason.
    func deferRefreshWhileDeleting(on host: SessionHost) -> Bool {
        guard hostsWithRunningDeletion.contains(host) else { return false }
        hostsToRefreshAfterDeletion.insert(host)
        return true
    }

    func isDeletionPending(for conversation: Conversation) -> Bool {
        pendingDeletionConversationIDs.contains(conversation.id)
    }

    func deletionPlan(for projectPath: String) -> SessionDeletionPlan {
        deletionPlan(for: conversations.filter { $0.projectDirectoryKey == projectPath })
    }

    func deletionPlan(for candidateConversations: [Conversation]) -> SessionDeletionPlan {
        SessionDeletionPlan(
            deletableConversations: candidateConversations.filter { !hasTerminal(for: $0) },
            openTerminalCount: candidateConversations.filter { hasTerminal(for: $0) }.count
        )
    }

    func delete(_ conversation: Conversation) {
        guard !hasTerminal(for: conversation) else {
            show(StoreAlert(
                title: SessionDeletionReport.oneSessionTitle(title(for: conversation)),
                message: ConversationDeletionError.activeTerminal.localizedDescription
            ))
            return
        }
        guard canStartDeletion(of: [conversation]), adapter(for: conversation.provider) != nil else { return }
        deleteInBackground([conversation])
    }

    func deleteSessions(in projectPath: String) {
        deleteConversations(conversations.filter { $0.projectDirectoryKey == projectPath })
    }

    /// Deletes every conversation in the list except those with open terminals.
    func deleteConversations(_ candidateConversations: [Conversation]) {
        let candidateIDs = Set(candidateConversations.map(\.id))
        let deletionPlan = deletionPlan(for: conversations.filter { candidateIDs.contains($0.id) })
        guard deletionPlan.hasDeletableConversations, canStartDeletion(of: deletionPlan.deletableConversations) else { return }

        deleteInBackground(deletionPlan.deletableConversations)
    }

    /// Try Again in the alert after a deletion: deletes again those of the sessions still listed and still
    /// deletable, through the same path as any deletion; does nothing when none are. While a deletion runs, or a
    /// host they are on is refreshing, the sessions wait and are deleted when that ends.
    func retryDeletion(of conversationIDs: Set<String>) {
        let deletionPlan = deletionPlan(for: conversations.filter { conversationIDs.contains($0.id) })
        guard deletionPlan.hasDeletableConversations else { return }
        guard canStartDeletion(of: deletionPlan.deletableConversations) else {
            queuedRetryConversationIDs.formUnion(conversationIDs)
            return
        }
        deleteInBackground(deletionPlan.deletableConversations)
    }

    /// Starts the Try Again that waited, when a deletion or a host's refresh ends. Still held up, it waits again;
    /// it is taken off the queue first, so it starts at most once.
    func startQueuedRetry() {
        guard !queuedRetryConversationIDs.isEmpty else { return }
        let conversationIDs = queuedRetryConversationIDs
        queuedRetryConversationIDs = []
        retryDeletion(of: conversationIDs)
    }

    /// Stops the running deletion after the session it is deleting, never during one. The sessions after it are
    /// not attempted and stay listed.
    func cancelDeletion() {
        guard let deletionTask, !deletionProgress.isStopping else { return }
        deletionProgress.markStopping()
        deletionTask.cancel()
    }

    /// Deletes the conversations one at a time off the main actor, then shows an alert if any could not be
    /// deleted; see `SessionDeletionReport`. A session already gone counts as deleted, and one whose file is gone
    /// leaves the list even when its deletion reported an error. Once an SSH host cannot be reached or does not
    /// respond in time, its remaining sessions are not attempted. Deleted sessions leave the list in groups, at
    /// most every `deletionListUpdateInterval`, so a long deletion does not re-render the sidebar per session.
    private func deleteInBackground(_ deletableConversations: [Conversation]) {
        pendingDeletionConversationIDs = Set(deletableConversations.map(\.id))
        hostsWithRunningDeletion = Set(deletableConversations.map(\.host))
        deletionProgress.start(totalCount: deletableConversations.count)
        let adapters = self.adapters
        let remoteDeletion = self.remoteDeletion
        let listUpdateInterval = deletionListUpdateInterval
        deletionTask = Task.detached(priority: .userInitiated) {
            let claudeIndexBatch = ClaudeDeletionIndexBatch()
            let clock = ContinuousClock()
            var lastListUpdate = clock.now
            var deletedSinceListUpdate: [Conversation] = []
            var deletedCount = 0
            var attemptedCount = 0
            var wasCanceled = false
            var failures: [ConversationDeletionFailure] = []
            var unresponsiveHosts: [String: UnresponsiveSSHHost] = [:]
            for conversation in deletableConversations {
                // Cancel takes effect between sessions, so no session is left half deleted.
                if Task.isCancelled {
                    wasCanceled = true
                    break
                }
                attemptedCount += 1
                if let unresponsiveHost = conversation.host.sshDestination.flatMap({ unresponsiveHosts[$0] }) {
                    failures.append(ConversationDeletionFailure(
                        conversation: conversation,
                        reason: RemoteConversationDeletionError.notAttempted(unresponsiveHost).localizedDescription,
                        unresponsiveHost: unresponsiveHost
                    ))
                } else if let adapter = adapters.first(where: { $0.provider == conversation.provider }) {
                    do {
                        try Self.deleteFromDisk(conversation, adapter: adapter, remoteDeletion: remoteDeletion, claudeIndexBatch: claudeIndexBatch)
                        deletedSinceListUpdate.append(conversation)
                    } catch ConversationDeletionError.missingSource {
                        // Already gone, as after an earlier deletion whose result was lost: it counts as deleted.
                        deletedSinceListUpdate.append(conversation)
                    } catch {
                        let unresponsiveHost = (error as? RemoteConversationDeletionError)?.unresponsiveHost
                        if let unresponsiveHost { unresponsiveHosts[unresponsiveHost.host] = unresponsiveHost }
                        let isFileGone = !FileManager.default.fileExists(atPath: conversation.sourceFile.path)
                        failures.append(ConversationDeletionFailure(
                            conversation: conversation,
                            reason: error.localizedDescription,
                            unresponsiveHost: unresponsiveHost,
                            isStillListed: !isFileGone
                        ))
                        if isFileGone { deletedSinceListUpdate.append(conversation) }
                    }
                }
                if clock.now - lastListUpdate >= listUpdateInterval || claudeIndexBatch.pendingCount >= ClaudeDeletionIndexBatch.maximumSessionCount {
                    failures += claudeIndexBatch.flush()
                    let deleted = deletedSinceListUpdate
                    let completedCount = attemptedCount
                    deletedCount += deleted.count
                    deletedSinceListUpdate = []
                    lastListUpdate = clock.now
                    await self.applyDeletionProgress(removing: deleted, completedCount: completedCount)
                }
            }
            failures += claudeIndexBatch.flush()
            let deleted = deletedSinceListUpdate
            let report = SessionDeletionReport(
                requestedCount: deletableConversations.count,
                deletedCount: deletedCount + deleted.count,
                failures: failures,
                wasCanceled: wasCanceled
            )
            await self.finishDeletion(removing: deleted, report: report)
        }
    }

    /// A session on this Mac is deleted by its tool's adapter; one on an SSH host over SSH.
    nonisolated private static func deleteFromDisk(
        _ conversation: Conversation,
        adapter: any ConversationAdapter,
        remoteDeletion: RemoteConversationDeletion,
        claudeIndexBatch: ClaudeDeletionIndexBatch
    ) throws {
        switch conversation.host {
        case .thisMac:
            if let claude = adapter as? ClaudeAdapter {
                try ClaudeConversationDeletion(configurationDirectory: claude.configurationDirectory, indexBatch: claudeIndexBatch).delete(conversation)
            } else { try adapter.delete(conversation) }
        case .ssh: try remoteDeletion.delete(conversation)
        }
    }

    private func applyDeletionProgress(removing deleted: [Conversation], completedCount: Int) {
        removeDeletedConversations(deleted)
        deletionProgress.update(completedCount: completedCount)
    }

    /// Always runs when a deletion ends, canceled or not, so another can start; then refreshes the hosts whose
    /// refresh waited for it, and starts a Try Again that waited, if nothing holds it up any more.
    private func finishDeletion(removing deleted: [Conversation], report: SessionDeletionReport) {
        // Before the deleted sessions' custom titles are forgotten, so the alert names them as the sidebar did.
        let reportAlert = report.alert(titleOf: title(for:))
        removeDeletedConversations(deleted)
        pendingDeletionConversationIDs = []
        deletionTask = nil
        deletionProgress.finish()
        if let reportAlert { show(reportAlert) }

        hostsWithRunningDeletion = []
        let hostsToRefresh = hostsToRefreshAfterDeletion
        hostsToRefreshAfterDeletion = []
        for host in hosts where hostsToRefresh.contains(host) { refresh(host) }
        startQueuedRetry()
    }

    /// Takes the deleted sessions off the list in one change, and forgets their custom titles and pins.
    private func removeDeletedConversations(_ deleted: [Conversation]) {
        guard !deleted.isEmpty else { return }
        let deletedIDs = Set(deleted.map(\.id))
        conversations.removeAll { deletedIDs.contains($0.id) }

        var remainingTitleAliases = titleAliases
        for conversationID in deletedIDs { remainingTitleAliases.removeTitle(forConversationID: conversationID) }
        if remainingTitleAliases != titleAliases {
            titleAliases = remainingTitleAliases
            titleAliases.save(to: userDefaults)
        }
        var remainingPinnedItems = pinnedItems
        for conversationID in deletedIDs { remainingPinnedItems.setPinned(false, conversationID: conversationID) }
        if remainingPinnedItems != pinnedItems {
            pinnedItems = remainingPinnedItems
            pinnedItems.save(to: userDefaults)
        }
    }

    // MARK: - Tabs

    /// Swaps a tab for another in the same place, closing the old one; keeps it selected if it was, and keeps
    /// its side of a split.
    func replaceTerminal(at index: Int, with session: TerminalSession) {
        defer { persistOpenTabs() }
        let replacedID = terminalSessions[index].id
        terminalSessions[index].close()
        terminalSessions[index] = session
        terminalSplitPair = terminalSplitPair?.replacing(replacedID, with: session.id)
        if selectedTerminalID == replacedID { selectedTerminalID = session.id }
    }

    /// Adds the tab after its project's other tabs, or at the end, and shows it.
    func openTerminal(_ session: TerminalSession) {
        defer { persistOpenTabs() }
        showProjectInSidebar(session.projectDirectoryKey)
        let insertionIndex = TerminalTabOrder.insertionIndex(
            forProjectKey: session.projectDirectoryKey,
            amongTabProjectKeys: terminalSessions.map(\.projectDirectoryKey)
        )
        terminalSessions.insert(session, at: insertionIndex)
        selectedTerminalID = session.id
    }

    /// Puts a tab reopened from the last quit at `index` without showing it, unless `selecting`.
    func insertReopenedTerminal(_ session: TerminalSession, at index: Int, selecting: Bool) {
        defer { persistOpenTabs() }
        showProjectInSidebar(session.projectDirectoryKey)
        terminalSessions.insert(session, at: min(index, terminalSessions.count))
        if selecting { selectedTerminalID = session.id }
    }

    var selectedTerminal: TerminalSession? {
        terminalSessions.first { $0.id == selectedTerminalID }
    }

    // MARK: - Split view

    /// The pair while the selected tab is half of it, when both panes show side by side.
    var shownSplitPair: TerminalSplitPair? {
        guard let terminalSplitPair, let selectedTerminalID, terminalSplitPair.contains(selectedTerminalID) else { return nil }
        return terminalSplitPair
    }

    /// Shows another tab side by side with the selected tab, which keeps the keyboard, as Chrome adds a tab to a
    /// split view. While the selected tab is half of the pair, the new tab takes its counterpart's place, so the
    /// selected tab keeps its side; otherwise the selected tab takes the left pane of a new pair, which replaces
    /// any other, as there is one split at a time. A reopened tab still waiting to be shown starts as it joins.
    func splitSelectedTerminal(with id: UUID) {
        guard let selectedTerminalID, selectedTerminalID != id,
              let joiningTab = terminalSessions.first(where: { $0.id == id }) else { return }
        if let terminalSplitPair, let counterpart = terminalSplitPair.counterpart(of: selectedTerminalID) {
            self.terminalSplitPair = terminalSplitPair.replacing(counterpart, with: id)
        } else {
            terminalSplitPair = TerminalSplitPair(leadingID: selectedTerminalID, trailingID: id)
        }
        joiningTab.startNowThatItIsShown()
    }

    func swapSplitSides() {
        terminalSplitPair = terminalSplitPair?.swapped
    }

    /// Unlinks the pair; the selected tab stays, alone again.
    func endSplit() {
        terminalSplitPair = nil
    }

    /// Leaving a new session's tab refreshes its host, so what its CLI saved so far is listed.
    func selectTerminal(_ id: UUID?) {
        guard selectedTerminalID != id else { return }
        defer { persistOpenTabs() }
        let leftNewSessionTab = selectedTerminalID == id ? nil : selectedTerminal.flatMap { $0.startsNewSession ? $0 : nil }
        selectedTerminalID = id
        if let leftNewSessionTab { refresh(leftNewSessionTab.host) }
    }

    func closeTerminal(_ id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        defer { persistOpenTabs() }
        let closedTab = terminalSessions[index]
        // Closing half of a split unlinks it; closing the shown half leaves the other half in front, full width.
        let splitCounterpart = terminalSplitPair?.counterpart(of: id)
        if splitCounterpart != nil { terminalSplitPair = nil }
        let indexToSelect = TerminalTabOrder.indexToSelect(
            afterClosingTabAt: index,
            amongTabProjectKeys: terminalSessions.map(\.projectDirectoryKey)
        )
        closedTab.close()
        terminalSessions.remove(at: index)
        if selectedTerminalID == id { selectedTerminalID = splitCounterpart ?? indexToSelect.map { terminalSessions[$0].id } }
        if closedTab.startsNewSession { refresh(closedTab.host) }
    }

    func closeAllTerminals() {
        defer { persistOpenTabs() }
        for session in terminalSessions { session.close() }
        terminalSessions = []
        terminalSplitPair = nil
        selectedTerminalID = nil
    }

    // MARK: - Errors

    /// The message of the alert shown, if any.
    var errorMessage: String? { alert?.message }

    /// Shows `message` under the general title.
    func showError(_ message: String) {
        show(StoreAlert(title: StoreAlert.defaultTitle, message: message))
    }

    /// Shows `newAlert` now, or after the alerts already shown or waiting are dismissed.
    func show(_ newAlert: StoreAlert) {
        if alert == nil {
            alert = newAlert
        } else {
            waitingAlerts.append(newAlert)
        }
    }

    /// Dismisses `dismissedAlert` if it is the one shown, then shows the next waiting one. An alert that already
    /// went, such as one whose closing reports late, leaves a newer one alone.
    func dismissAlert(_ dismissedAlert: StoreAlert) {
        guard alert?.id == dismissedAlert.id else { return }
        alert = waitingAlerts.isEmpty ? nil : waitingAlerts.removeFirst()
    }

    /// Dismisses the alert shown, if any.
    func dismissError() {
        if let alert { dismissAlert(alert) }
    }
}
