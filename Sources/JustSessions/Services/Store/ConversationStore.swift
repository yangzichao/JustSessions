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
    /// Every listed session's messages, read while a window's search has text; see `SessionMessageIndexer`.
    let messageIndexer = SessionMessageIndexer()
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
    /// Pairs of tabs linked side by side, as in Chrome's split view, any number of them, with a tab in at most one.
    /// A split outlives the selection; both its terminals show only while one of them is selected, see `shownSplit`.
    @Published private(set) var terminalSplits: [TerminalSplit] = []
    /// Every conversation queued in the running deletion, of one session or several. It changes only when a
    /// deletion starts, when sessions join it, and when it ends; `deletionProgress` follows the sessions in between.
    @Published private(set) var pendingDeletionConversationIDs: Set<String> = []
    /// Sessions asked to be deleted while a host they are on was refreshing, or while a deletion was stopping.
    /// They are deleted when that ends; see `startQueuedDeletion()`.
    @Published private(set) var queuedDeletionConversationIDs: Set<String> = []
    /// How far the running deletion has got. Only the sidebar's progress bar observes it.
    let deletionProgress = SessionDeletionProgress()
    /// The SSH hosts listed after this Mac.
    @Published var remoteHostList: RemoteHostList
    /// SSH hosts whose tmux sessions keep the host's own prefix keys; see `ConversationStore+RemoteTmuxPrefix`.
    @Published var remoteHostsUsingTmuxPrefix: RemoteHostsUsingTmuxPrefix
    /// Commands of your own that tools' CLIs start with, per host; see `ConversationStore+StartCommands`.
    @Published var cliStartCommands: CLIStartCommands
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
    /// Sessions asked to be deleted while a deletion ran. It goes on to them once it has deleted those before
    /// them, so they share its progress bar and its report; see `joinRunningDeletion(_:)`.
    private var sessionsJoiningRunningDeletion: [Conversation] = []
    /// What the running deletion's finished rounds did. Each round after the first deletes the sessions that
    /// joined during the one before.
    private var finishedDeletionRounds: SessionDeletionReport?
    private var deletionTask: Task<Void, Never>?
    /// Deleted sessions leave the list, and the progress bar moves, at most this often while a deletion runs, and
    /// once more when it ends. Tests set it to zero to follow each session.
    var deletionListUpdateInterval: Duration = .milliseconds(500)

    private let adapters: [any ConversationAdapter]
    let commandResolver: NativeCLICommandResolver
    /// Deletes sessions on SSH hosts.
    private let remoteDeletion: RemoteConversationDeletion
    /// Where custom titles, project names, pins, sidebar projects, SSH hosts, and start commands are kept.
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
        self.remoteHostsUsingTmuxPrefix = RemoteHostsUsingTmuxPrefix.load(from: userDefaults)
        self.cliStartCommands = CLIStartCommands.load(from: userDefaults)
        LoginShellPathReader.warmUpInBackground()
        ClaudeSessionIDFlagSupport.shared.warmUpInBackground()
        if startsBackgroundPolling {
            startClaudeLiveNameSync()
            startAppendedSessionNameFollowing()
            startCodexThreadFollowing()
            startLiveSessionFollowing()
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
                self.startQueuedDeletion()
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

    /// One session has nothing to cancel between, so only a deletion of several shows the sidebar's progress bar.
    var isDeletingSeveralSessions: Bool {
        pendingDeletionConversationIDs.count > 1
    }

    /// Returns true when a deletion runs on `host`; its refresh then starts once the deletion ends: it may read a
    /// session before it is deleted and list it again.
    func deferRefreshWhileDeleting(on host: SessionHost) -> Bool {
        guard hostsWithRunningDeletion.contains(host) else { return false }
        hostsToRefreshAfterDeletion.insert(host)
        return true
    }

    /// Being deleted, or waiting to be.
    func isDeletionPending(for conversation: Conversation) -> Bool {
        pendingDeletionConversationIDs.contains(conversation.id) || queuedDeletionConversationIDs.contains(conversation.id)
    }

    func deletionPlan(for projectPath: String) -> SessionDeletionPlan {
        deletionPlan(forProjects: [projectPath])
    }

    func deletionPlan(forProjects projectPaths: Set<String>) -> SessionDeletionPlan {
        deletionPlan(for: conversations.filter { projectPaths.contains($0.projectDirectoryKey) })
    }

    /// Sessions already being deleted, or waiting to be, are left out: they are not deleted twice.
    func deletionPlan(for candidateConversations: [Conversation]) -> SessionDeletionPlan {
        let notYetPending = candidateConversations.filter { !isDeletionPending(for: $0) }
        return SessionDeletionPlan(
            deletableConversations: notYetPending.filter { !hasTerminal(for: $0) },
            openTerminalCount: notYetPending.filter { hasTerminal(for: $0) }.count
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
        guard adapter(for: conversation.provider) != nil else { return }
        deleteConversations([conversation])
    }

    func deleteSessions(in projectPath: String) {
        deleteConversations(conversations.filter { $0.projectDirectoryKey == projectPath })
    }

    /// Deletes every conversation in the list except those with open terminals and those already being deleted.
    func deleteConversations(_ candidateConversations: [Conversation]) {
        let candidateIDs = Set(candidateConversations.map(\.id))
        let deletionPlan = deletionPlan(for: conversations.filter { candidateIDs.contains($0.id) })
        startOrQueueDeletion(of: deletionPlan.deletableConversations)
    }

    /// Try Again in the alert after a deletion: deletes again those of the sessions still listed and still
    /// deletable, through the same path as any deletion; does nothing when none are.
    func retryDeletion(of conversationIDs: Set<String>) {
        deleteConversations(conversations.filter { conversationIDs.contains($0.id) })
    }

    /// Starts the sessions that waited, when a deletion or a host's refresh ends. Still held up, they wait again;
    /// they are taken off the queue first, so each wait ends at most once.
    func startQueuedDeletion() {
        guard !queuedDeletionConversationIDs.isEmpty else { return }
        let conversationIDs = queuedDeletionConversationIDs
        queuedDeletionConversationIDs = []
        retryDeletion(of: conversationIDs)
    }

    /// Stops the running deletion after the session it is deleting, never during one. The sessions after it,
    /// including those that joined it, are not attempted and stay listed.
    func cancelDeletion() {
        guard let deletionTask, !deletionProgress.isStopping else { return }
        deletionProgress.markStopping()
        deletionTask.cancel()
    }

    /// Starts deleting the sessions, or adds them to the running deletion. Sessions on a host being refreshed wait
    /// for the refresh to end, as it may have read a session before it was deleted and would list it again; those
    /// asked for while a deletion stops wait for it to end.
    private func startOrQueueDeletion(of deletableConversations: [Conversation]) {
        guard !deletableConversations.isEmpty else { return }
        let isHostRefreshing = deletableConversations.contains { hostRefreshStatuses[$0.host] == .refreshing }
        if isHostRefreshing || deletionProgress.isStopping {
            queuedDeletionConversationIDs.formUnion(deletableConversations.map(\.id))
        } else if isDeletingSessions {
            joinRunningDeletion(deletableConversations)
        } else {
            pendingDeletionConversationIDs = Set(deletableConversations.map(\.id))
            hostsWithRunningDeletion = Set(deletableConversations.map(\.host))
            deletionProgress.start(totalCount: deletableConversations.count)
            deleteRoundInBackground(deletableConversations)
        }
    }

    /// The running deletion deletes these sessions once it has deleted those before them. Their hosts' refreshes
    /// wait from now on, so nothing holds them up when their turn comes.
    private func joinRunningDeletion(_ deletableConversations: [Conversation]) {
        sessionsJoiningRunningDeletion += deletableConversations
        pendingDeletionConversationIDs.formUnion(deletableConversations.map(\.id))
        hostsWithRunningDeletion.formUnion(deletableConversations.map(\.host))
        deletionProgress.add(sessionCount: deletableConversations.count)
    }

    /// Deletes the conversations one at a time off the main actor, then shows an alert if any could not be
    /// deleted; see `SessionDeletionReport`. A session already gone counts as deleted, and one whose file is gone
    /// leaves the list even when its deletion reported an error. Once an SSH host cannot be reached or does not
    /// respond in time, its remaining sessions are not attempted, in this round or a later one. Deleted sessions
    /// leave the list in groups, at most every `deletionListUpdateInterval`, so a long deletion does not
    /// re-render the sidebar per session.
    private func deleteRoundInBackground(_ deletableConversations: [Conversation]) {
        let adapters = self.adapters
        let remoteDeletion = self.remoteDeletion
        let listUpdateInterval = deletionListUpdateInterval
        let completedCountBeforeRound = deletionProgress.completedCount
        let unresponsiveHostsBeforeRound = finishedDeletionRounds?.unresponsiveHosts ?? [:]
        deletionTask = Task.detached(priority: .userInitiated) {
            let claudeIndexBatch = ClaudeDeletionIndexBatch()
            let clock = ContinuousClock()
            var lastListUpdate = clock.now
            var deletedSinceListUpdate: [Conversation] = []
            var deletedCount = 0
            var attemptedCount = 0
            var wasCanceled = false
            var failures: [ConversationDeletionFailure] = []
            var unresponsiveHosts = unresponsiveHostsBeforeRound
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
                    let completedCount = completedCountBeforeRound + attemptedCount
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
            await self.finishDeletionRound(removing: deleted, report: report)
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

    /// Goes on to the sessions that joined the deletion during this round, unless Cancel was chosen; then they are
    /// not attempted, and the deletion ends.
    private func finishDeletionRound(removing deleted: [Conversation], report roundReport: SessionDeletionReport) {
        var report = finishedDeletionRounds.map { $0.followed(by: roundReport) } ?? roundReport
        let joinedSessions = sessionsJoiningRunningDeletion
        sessionsJoiningRunningDeletion = []
        guard !joinedSessions.isEmpty else {
            finishDeletion(removing: deleted, report: report)
            return
        }
        guard !report.wasCanceled, !deletionProgress.isStopping else {
            report = report.followed(by: SessionDeletionReport(
                requestedCount: joinedSessions.count, deletedCount: 0, failures: [], wasCanceled: true
            ))
            finishDeletion(removing: deleted, report: report)
            return
        }
        applyDeletionProgress(removing: deleted, completedCount: report.requestedCount)
        finishedDeletionRounds = report
        deleteRoundInBackground(joinedSessions)
    }

    /// Always runs when a deletion ends, canceled or not, so another can start; then refreshes the hosts whose
    /// refresh waited for it, and starts the sessions that waited, if nothing holds them up any more.
    private func finishDeletion(removing deleted: [Conversation], report: SessionDeletionReport) {
        // Before the deleted sessions' custom titles are forgotten, so the alert names them as the sidebar did.
        let reportAlert = report.alert(titleOf: title(for:))
        removeDeletedConversations(deleted)
        pendingDeletionConversationIDs = []
        finishedDeletionRounds = nil
        deletionTask = nil
        deletionProgress.finish()
        if let reportAlert { show(reportAlert) }

        hostsWithRunningDeletion = []
        let hostsToRefresh = hostsToRefreshAfterDeletion
        hostsToRefreshAfterDeletion = []
        for host in hosts where hostsToRefresh.contains(host) { refresh(host) }
        startQueuedDeletion()
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

    /// Swaps a tab for another in the same place, closing the old one; keeps it selected if it was, and hands it the
    /// old tab's place in a split.
    func replaceTerminal(at index: Int, with session: TerminalSession) {
        defer { persistOpenTabs() }
        let replacedID = terminalSessions[index].id
        terminalSessions[index].close()
        terminalSessions[index] = session
        if terminalSplits.contains(where: { $0.contains(replacedID) }) {
            terminalSplits = terminalSplits.map { $0.replacing(replacedID, with: session.id) }
        }
        if selectedTerminalID == replacedID { selectedTerminalID = session.id }
    }

    /// Adds the tab after the last tab of its project's group, which may be a split's, or at the end, and shows it.
    func openTerminal(_ session: TerminalSession) {
        defer { persistOpenTabs() }
        showProjectInSidebar(session.projectDirectoryKey)
        terminalSessions.insert(session, at: tabStrip.insertionIndex(forNewTabOfProject: session.projectDirectoryKey))
        selectedTerminalID = session.id
    }

    /// Puts a tab reopened from the last quit at `index` without showing it, unless `selecting`. Where a tab at
    /// `index` would part a split's two tabs or sit among another group's tabs, it goes where a new tab of its
    /// project opens instead.
    func insertReopenedTerminal(_ session: TerminalSession, at index: Int, selecting: Bool) {
        defer { persistOpenTabs() }
        showProjectInSidebar(session.projectDirectoryKey)
        let index = tabStrip.insertionIndex(forReopenedTabOfProject: session.projectDirectoryKey, at: index)
        terminalSessions.insert(session, at: index)
        if selecting { selectedTerminalID = session.id }
    }

    var selectedTerminal: TerminalSession? {
        terminalSessions.first { $0.id == selectedTerminalID }
    }

    // MARK: - Split view

    /// The tabs and splits as `TerminalTabStrip` orders them.
    var tabStrip: TerminalTabStrip {
        TerminalTabStrip(
            tabs: terminalSessions.map { TerminalTabStrip.Tab(id: $0.id, projectKey: $0.projectDirectoryKey) },
            splits: terminalSplits
        )
    }

    /// Takes on the strip's order and splits, changing only what differs.
    func apply(_ strip: TerminalTabStrip) {
        let tabIDs = strip.tabIDs
        if tabIDs != terminalSessions.map(\.id) {
            let tabsByID = Dictionary(uniqueKeysWithValues: terminalSessions.map { ($0.id, $0) })
            terminalSessions = tabIDs.compactMap { tabsByID[$0] }
        }
        if strip.splits != terminalSplits { terminalSplits = strip.splits }
    }

    func split(containing tabID: UUID) -> TerminalSplit? {
        terminalSplits.first { $0.contains(tabID) }
    }

    /// The split's left and right tabs: the one that comes first in the tab bar shows on the left, as in Chrome.
    func sides(of split: TerminalSplit) -> TerminalSplit.Sides? {
        tabStrip.sides(of: split)
    }

    /// The tab group the tab shows in, by project key: its split's group while it is in one, or else its project's.
    /// Tabs of one group always sit together in `terminalSessions`.
    func tabGroupKey(of tab: TerminalSession) -> String {
        split(containing: tab.id)?.groupKey ?? tab.projectDirectoryKey
    }

    /// Every tab's group key, in tab bar order.
    var tabGroupKeys: [String] {
        terminalSessions.map(tabGroupKey(of:))
    }

    /// The split while the selected tab is in it, when both its panes show side by side.
    var shownSplit: TerminalSplit? {
        selectedTerminalID.flatMap(split(containing:))
    }

    /// The tabs in the order they would take with every split separated. Splits are not saved across quits, so
    /// this is the order the tabs reopen in, with no tab inside another project's group.
    var terminalSessionsWithSplitsSeparated: [TerminalSession] {
        var strip = tabStrip
        strip.separateAllSplits()
        let tabsByID = Dictionary(uniqueKeysWithValues: terminalSessions.map { ($0.id, $0) })
        return strip.tabIDs.compactMap { tabsByID[$0] }
    }

    /// Shows another tab side by side with the selected tab, which stays selected, as Chrome's AddToNewSplit; see
    /// `TerminalTabStrip.addSplit(joining:beside:splitID:)` for where the other tab moves. Neither tab may be in a
    /// split already. A reopened tab still waiting to be shown starts as it joins.
    func splitSelectedTerminal(with id: UUID) {
        guard let selectedTerminalID, let joiningTab = terminalSessions.first(where: { $0.id == id }) else { return }
        var strip = tabStrip
        guard strip.addSplit(joining: id, beside: selectedTerminalID) != nil else { return }
        defer { persistOpenTabs() }
        apply(strip)
        joiningTab.startNowThatItIsShown()
    }

    /// The split's tabs trade places in the tab bar, so its panes trade sides. The selection stays.
    func reverseSplit(_ splitID: UUID) {
        var strip = tabStrip
        strip.reverseSplit(splitID)
        guard strip != tabStrip else { return }
        defer { persistOpenTabs() }
        apply(strip)
    }

    /// Unlinks the split, keeping both tabs open and the selection; a tab from another project goes back to its
    /// project's tabs. The shown split's tab that is not selected goes off screen.
    func separateSplit(_ splitID: UUID) {
        guard terminalSplits.contains(where: { $0.id == splitID }) else { return }
        defer { persistOpenTabs() }
        var strip = tabStrip
        strip.separateSplit(splitID)
        refreshingHostsOfNewSessionsLeavingTheScreen { apply(strip) }
    }

    /// Puts a tab in no split into the shown split in place of the tab on `side`, as Chrome's "Move tab into split
    /// view": the two trade places in the tab bar, and the tab swapped out goes back to its project's tabs when it
    /// lands among another project's, and goes off screen. When the tab swapped out was selected, the incoming tab is
    /// selected instead. A reopened tab still waiting to be shown starts as it joins.
    func moveIntoShownSplit(_ tabID: UUID, swappingWith side: TerminalSplit.Side) {
        guard let shownSplit, let sides = sides(of: shownSplit),
              let incomingTab = terminalSessions.first(where: { $0.id == tabID }) else { return }
        let outgoingID = sides.tabID(on: side)
        var strip = tabStrip
        guard strip.swap(tabID, intoSplit: shownSplit.id, replacing: outgoingID) else { return }
        defer { persistOpenTabs() }
        refreshingHostsOfNewSessionsLeavingTheScreen {
            apply(strip)
            if selectedTerminalID == outgoingID { selectedTerminalID = tabID }
        }
        incomingTab.startNowThatItIsShown()
    }

    /// The tabs whose terminals are on screen: both tabs of a shown split, or else the selected tab.
    private var terminalIDsOnScreen: Set<UUID> {
        if let shownSplit { return shownSplit.tabIDs }
        return selectedTerminalID.map { [$0] } ?? []
    }

    /// Makes `change`, then refreshes the host of every new session's tab it took off screen, so what its CLI saved so
    /// far is listed.
    private func refreshingHostsOfNewSessionsLeavingTheScreen(_ change: () -> Void) {
        let shownBefore = terminalIDsOnScreen
        change()
        let shownAfter = terminalIDsOnScreen
        var hostsToRefresh: [SessionHost] = []
        for tab in terminalSessions where tab.startsNewSession && shownBefore.contains(tab.id) && !shownAfter.contains(tab.id) {
            if !hostsToRefresh.contains(tab.host) { hostsToRefresh.append(tab.host) }
        }
        for host in hostsToRefresh { refresh(host) }
    }

    /// A new session's tab that goes off screen refreshes its host, so what its CLI saved so far is listed.
    /// Moving between the two panes of a shown split keeps both on screen, so it refreshes nothing.
    func selectTerminal(_ id: UUID?) {
        guard selectedTerminalID != id else { return }
        defer { persistOpenTabs() }
        refreshingHostsOfNewSessionsLeavingTheScreen { selectedTerminalID = id }
    }

    /// Closing a tab of a split unlinks it, and the other tab goes back to its project's tabs; closing the selected
    /// one leaves the other in front, full width. Closing any other selected tab shows a neighbor in its group.
    func closeTerminal(_ id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        defer { persistOpenTabs() }
        let closedTab = terminalSessions[index]
        var remainingTabIDs = terminalSessions.map(\.id)
        remainingTabIDs.remove(at: index)
        let neighborToSelect = TerminalTabOrder.indexToSelect(afterClosingTabAt: index, amongTabProjectKeys: tabGroupKeys)
            .map { remainingTabIDs[$0] }
        let tabToSelect = split(containing: id)?.partner(of: id) ?? neighborToSelect
        var strip = tabStrip
        strip.removeTab(id)
        closedTab.close()
        apply(strip)
        if selectedTerminalID == id { selectedTerminalID = tabToSelect }
        if closedTab.startsNewSession { refresh(closedTab.host) }
    }

    func closeAllTerminals() {
        defer { persistOpenTabs() }
        for session in terminalSessions { session.close() }
        terminalSplits = []
        terminalSessions = []
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
