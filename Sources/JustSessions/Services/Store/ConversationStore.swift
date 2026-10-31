import Combine
import Foundation
import Observation

/// The listed sessions and open tabs. State changes here; the `ConversationStore+…` extensions build on the
/// methods below to refresh hosts, launch CLIs, and link new sessions to their tabs.
/// Observed property by property (`@Observable`): a view re-runs only when a property it read changes, so selecting a tab
/// re-runs only what shows the selection rather than every row; see item 25 in docs/development/performance.md.
@MainActor
@Observable
final class ConversationStore {
    private(set) var conversations: [Conversation] = [] {
        didSet {
            conversationIndex = ConversationIndex(conversations)
            conversationsRevision &+= 1
        }
    }
    private(set) var conversationIndex = ConversationIndex([])
    /// Sessions subagents ran in, newest first. They stay out of `conversations`, so only the rows of the sessions that
    /// started them list them, and nothing that follows listed sessions, such as linking a new tab, mistakes one for
    /// a session of its own.
    private(set) var subagentConversations: [Conversation] = [] {
        didSet { subagentIndex = SubagentConversationIndex(subagentConversations) }
    }
    private(set) var subagentIndex = SubagentConversationIndex([])
    /// Changes with every change to `conversations`, so what is worked out from them knows when to work it out again.
    private(set) var conversationsRevision = 0
    /// What the sidebar lists, kept until what it was worked out from changes; see `ConversationStore+SidebarProjects`.
    @ObservationIgnored var cachedSidebarProjection: SidebarProjection?
    /// What the browser last showed for its filters, kept the same way; see `ConversationStore+SidebarProjects`.
    @ObservationIgnored var cachedFilteredSidebarProjection: FilteredSidebarProjection?
    /// Every listed session's messages, shared by the app's workspace windows while any of them searches.
    var messageIndexer: SessionMessageIndexer { readService.messageIndexer }
    /// What the main window's alert shows, if anything.
    private(set) var alert: StoreAlert?
    /// Whether the window shows All Bookmarks (RDR-52), which Bookmarks → Show All Bookmarks… asks for (`AllBookmarksCommand`).
    var showsAllBookmarks = false
    /// Alerts that came while `alert` was shown. Each is shown once the ones before it are dismissed, since
    /// SwiftUI keeps showing an alert whose content changes under it.
    private var waitingAlerts: [StoreAlert] = []
    private(set) var titleAliases: ConversationTitleAliases
    private(set) var projectDisplayNames: ProjectDisplayNames
    private(set) var pinnedItems: PinnedItems
    private(set) var archivedSessions: ArchivedSessions
    private(set) var messageBookmarks: MessageBookmarks
    private(set) var sessionsDeletedWhenTabCloses: SessionsDeletedWhenTabCloses
    var sidebarProjectList: SidebarProjectList
    private var terminalSessionsStorage: [TerminalSession] = [] {
        didSet {
            windowRegistry.tabsChanged(in: self)
            followTabStateChanges()
            forgetClosedTabsInSplitChoosers()
        }
    }
    /// Each open tab's own changes, which count in `tabStateRevision`, and its CLI ending; see `followTabStateChanges()`.
    @ObservationIgnored private var tabStateSubscriptions: [UUID: [AnyCancellable]] = [:]
    /// The open tabs, in tab bar order. Reading them also reads `tabStateRevision`, so a view that looks at tabs
    /// through the store re-runs when a tab's own state changes, which the store does not see otherwise.
    private(set) var terminalSessions: [TerminalSession] {
        get {
            _ = tabStateRevision
            return terminalSessionsStorage
        }
        set { terminalSessionsStorage = newValue }
    }
    /// Counts changes to the tabs' own state that views reading tabs through the store must see: any open tab's own
    /// change, such as its CLI's activity or its CLI ending, and another window's tabs. See `noteTabStateChanged()`.
    private(set) var tabStateRevision = 0
    /// Selecting a tab that waited to be shown starts it; see `TerminalSession.isWaitingToBeShown`.
    private(set) var selectedTerminalID: UUID? {
        didSet {
            selectedTerminal?.startNowThatItIsShown()
            markTerminalsOnScreenSeen()
            guard selectedTerminalID != oldValue else { return }
            selectsShownSplitChooser = false
            if let selectedTerminalID {
                tabIDsByLastSelected.removeAll { $0 == selectedTerminalID }
                tabIDsByLastSelected.insert(selectedTerminalID, at: 0)
            }
        }
    }
    /// Pairs of tabs linked side by side, as in Chrome's split view, any number of them, with a tab in at most one.
    /// A split outlives the selection; both its terminals show only while one of them is selected, see `shownSplit`.
    private(set) var terminalSplits: [TerminalSplit] = [] {
        didSet {
            markTerminalsOnScreenSeen()
            forgetClosedTabsInSplitChoosers()
            forgetOrientationsOfClosedSplitViews()
        }
    }
    /// Splits whose other view is still to be chosen, each beside a tab open here in no split, at most one per tab. Like
    /// a split, one outlives the selection and shows while its tab is selected; see `ConversationStore+SplitChooser`.
    var terminalSplitChoosers: [TerminalSplitChooser] = [] {
        didSet { if shownSplitChooser == nil { selectsShownSplitChooser = false } }
    }
    /// The shown split chooser has the keyboard rather than the tab beside it, as Chrome's split view page is the
    /// active tab while it shows. Selecting another tab gives the keyboard back to tabs.
    var selectsShownSplitChooser = false
    /// The splits and split choosers whose views are stacked rather than side by side, by id; see
    /// `ConversationStore+SplitOrientation`. A chooser's carries over to the split it becomes, which takes its id.
    var stackedSplitViewIDs: Set<UUID> = []
    /// The open tabs by when they were last selected, the latest first, which is the order a split chooser lists them in.
    private(set) var tabIDsByLastSelected: [UUID] = []
    /// The split chooser whose New Session… is open: the next tab to open takes its place; see `openTerminal`.
    @ObservationIgnored var splitChooserAwaitingNewTab: UUID?
    /// Every conversation queued in the running deletion, of one session or several. It changes only when a
    /// deletion starts, when sessions join it, and when it ends; `deletionProgress` follows the sessions in between.
    private(set) var pendingDeletionConversationIDs: Set<String> = []
    /// Sessions asked to be deleted while a host they are on was refreshing, or while a deletion was stopping.
    /// They are deleted when that ends; see `startQueuedDeletion()`.
    private(set) var queuedDeletionConversationIDs: Set<String> = []
    /// How far the running deletion has got. Only the sidebar's progress bar observes it.
    let deletionProgress = SessionDeletionProgress()
    /// The SSH hosts listed after this Mac.
    var remoteHostList: RemoteHostList
    /// SSH hosts whose tmux sessions keep the host's own prefix keys; see `ConversationStore+RemoteTmuxPrefix`.
    var remoteHostsUsingTmuxPrefix: RemoteHostsUsingTmuxPrefix
    /// SSH hosts you disconnected from, which the app leaves alone; see `ConversationStore+RemoteHostDisconnect`.
    var disconnectedRemoteHosts: DisconnectedRemoteHosts
    /// Disconnect's question about the host's open tabs, while it shows; see `HostDisconnectConfirmation`.
    var hostDisconnectQuestion: HostDisconnectQuestion?
    /// Lists an SSH host's sessions, copying them over SSH; see `refreshRemoteHost(_:discovery:)`. Tests copy from a
    /// local folder.
    @ObservationIgnored var remoteSessionDiscovery = RemoteSessionDiscovery()
    /// Commands of your own that tools' CLIs start with, per host; see `ConversationStore+StartCommands`.
    var cliStartCommands: CLIStartCommands
    /// Each SSH host's last shell startup check; see `ConversationStore+RemoteShellStartup`.
    var remoteShellStartupChecks: RemoteShellStartupChecks
    /// SSH hosts whose shell startup is being checked now.
    var hostsCheckingShellStartup: Set<String> = []
    /// SSH hosts checked again in this run because a refresh suggested their startup changed, so a host whose startup
    /// keeps getting in the way is not checked on every refresh.
    var hostsRecheckedShellStartup: Set<String> = []
    /// The host check this window shows, while it runs and once it has a report; see `ConversationStore+HostCheck`.
    var hostCheck: HostCheckSheetState?
    /// Each SSH host's last host check, which its heading warns of; see `ConversationStore+BackgroundHostCheck`.
    var keptHostChecks: KeptHostChecks
    /// What each SSH host's tmux printed at its last refresh when it couldn't reach the tmux server running there.
    var tmuxServerProblemsByHost: [String: String] = [:]
    /// SSH hosts whose tab ended soon after it started, for `HostBackgroundChecker` to check.
    @ObservationIgnored var hostsAskingForBackgroundCheck: Set<String> = []
    /// Each host's last refresh, this Mac's included.
    var hostRefreshStatuses: [SessionHost: HostRefreshStatus] = [:]
    /// When this window's copies of each SSH host started and ended; see `RemoteHostCopies`. Nothing shows it.
    @ObservationIgnored var remoteHostCopies = RemoteHostCopies()
    /// SSH hosts whose last refresh asked for a password, a code, or a new host key's approval, so their headings
    /// offer Connect…; see `ConversationStore+SSHLogin`.
    var sshHostsNeedingLogIn: Set<String> = []
    /// SSH hosts this window is logging in to with Connect… now.
    var sshHostsLoggingIn: Set<String> = []
    /// SSH hosts with a login made with Connect… open, in any window; see `SSHLoginConnections`.
    var sshHostsLoggedIn: Set<String> = []
    /// The tool each SSH host's running refresh is copying; see `RemoteSessionCopyStep`.
    var remoteSessionCopySteps: [SessionHost: RemoteSessionCopyStep] = [:]
    /// tmux sessions JustSessions started that still run, per host, as of the host's last refresh. On this Mac, one
    /// whose CLI ends leaves within about a second; see `ConversationStore+CLIActivitySync`.
    var tmuxSessionNamesByHost: [SessionHost: Set<String>] = [:]
    /// The tools whose CLI each host has, as of the host's last refresh; a host not checked yet is missing.
    /// See `ConversationStore+InstalledCLIs`.
    var installedProvidersByHost: [SessionHost: Set<ConversationProvider>] = [:]
    /// What the CLI of each session running in tmux with no tab open is doing, on this Mac or an SSH host, by
    /// conversation id. A tab's own CLI is on the tab; see `TerminalSession.cliActivity`.
    var detachedCLIActivities: [String: CLIActivity] = [:]
    /// Reads what such sessions on SSH hosts do; shared by every window. Tests set theirs.
    @ObservationIgnored var remoteDetachedActivityReader = RemoteDetachedActivityReader.shared
    /// When each session on an SSH host was first seen running in tmux with no tab, by `host` and tmux name, so only a
    /// later listing of the host that leaves it out says its CLI ended.
    @ObservationIgnored var remoteDetachedSince: [RemoteTmuxSessionKey: Date] = [:]
    /// The CLI of each tmux session on this Mac, by session name, as of the last refresh or the closing of its tab.
    var thisMacTmuxPaneProcessIDs: [String: Int32] = [:]
    /// Renames and kills of tmux sessions, in order per host; see `ConversationStore+Tmux`.
    let tmuxCommandQueues = TmuxCommandQueues()
    let codexTurnTracker = CodexRolloutTurnTracker()
    /// Each window's own, which closes its connection while the window runs no Codex CLI. Tests set theirs.
    var codexWaitReader = CodexAppServerWaitReader.forThisApp()
    /// What each CLI on this Mac did at the last activity sync; see `ConversationStore+CLIActivitySync`.
    var sessionAttentionTracker = SessionAttentionTracker()
    /// CLIs on this Mac that finished a turn while off screen; see `ConversationStore+UnseenFinishedTurns`.
    var unseenFinishedTurns = UnseenFinishedTurns()
    /// When each CLI on this Mac started waiting on you; see `ConversationStore+NotificationBell`.
    var waitingForYouStartTimes = WaitingForYouStartTimes()
    /// Tabs from the last quit still waiting for their host's sessions; see `ConversationStore+TabReopening`.
    var pendingTabReopening = PendingTabReopening()
    let tabPersistenceWindowID = UUID()
    var openTabPersistence: OpenTabPersistence?
    var isRestoringTabBatch = false
    var isTearingDownWorkspace = false
    /// Tabs closed in this window, for Reopen Closed Tab; see `ConversationStore+ReopeningClosedTabs`.
    var recentlyClosedTabs = RecentlyClosedTabs()
    var isClosingTabsWithoutRemembering = false
    let sessionNotifier: any SessionNotifying
    /// The app's windows, whose tabs this window's count with its own; see `ConversationStore+OtherWindows`.
    let windowRegistry: WorkspaceWindowRegistry
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
    @ObservationIgnored private var thisMacRefreshTask: Task<Void, Never>?
    /// Deleted sessions leave the list, and the progress bar moves, at most this often while a deletion runs, and
    /// once more when it ends. Tests set it to zero to follow each session.
    var deletionListUpdateInterval: Duration = .milliseconds(500)

    private let readService: WorkspaceReadService
    private let adapters: [any ConversationAdapter]
    let commandResolver: NativeCLICommandResolver
    /// Deletes sessions on SSH hosts.
    private let remoteDeletion: RemoteConversationDeletion
    /// Which SSH hosts' `claude` takes a new session's id; see `ConversationStore+RemoteClaudeSessionIDs`.
    let remoteClaudeSessionIDFlagSupport: RemoteClaudeSessionIDFlagSupport
    /// Finds out whether an SSH host's shell startup gets in the way; see `ConversationStore+RemoteShellStartup`.
    let remoteShellStartupCheck: RemoteShellStartupCheck
    /// Check this host…; see `ConversationStore+HostCheck`.
    let remoteHostCheck: RemoteHostCheck
    /// Where custom titles, project names, pins, sidebar projects, SSH hosts, and start commands are kept.
    let userDefaults: UserDefaults
    /// The engine new tabs' terminals open with.
    let terminalEngineStore: TerminalEngineStore
    /// Each host's choice of what closing a CLI tab does, which a removed SSH host's goes with.
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore

    init(
        adapters: [any ConversationAdapter] = [
            ClaudeAdapter(), CodexAdapter(), AntigravityAdapter(), KiroAdapter(), OpenCodeAdapter(), PiAdapter(),
        ],
        commandResolver: NativeCLICommandResolver = NativeCLICommandResolver(),
        userDefaults: UserDefaults = .standard,
        sessionNotifier: any SessionNotifying = SessionNotificationCenter.shared,
        windowRegistry: WorkspaceWindowRegistry = WorkspaceWindowRegistry(),
        remoteDeletion: RemoteConversationDeletion = RemoteConversationDeletion(),
        remoteClaudeSessionIDFlagSupport: RemoteClaudeSessionIDFlagSupport = .shared,
        remoteShellStartupCheck: RemoteShellStartupCheck = RemoteShellStartupCheck(),
        remoteHostCheck: RemoteHostCheck = RemoteHostCheck(),
        // Unlike the settings above, the engine and the close choices come from the shared stores, which read the
        // standard defaults; a test that depends on one passes its own store.
        terminalEngineStore: TerminalEngineStore = .shared,
        tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore = .shared,
        startsBackgroundPolling: Bool = true,
        readService: WorkspaceReadService? = nil
    ) {
        let readService = readService ?? WorkspaceReadService(adapters: adapters, commandResolver: commandResolver)
        self.readService = readService
        self.adapters = readService.adapters
        self.commandResolver = readService.commandResolver
        self.remoteDeletion = remoteDeletion
        self.remoteClaudeSessionIDFlagSupport = remoteClaudeSessionIDFlagSupport
        self.remoteShellStartupCheck = remoteShellStartupCheck
        self.remoteHostCheck = remoteHostCheck
        self.userDefaults = userDefaults
        self.terminalEngineStore = terminalEngineStore
        self.tabCloseChoiceSettingsStore = tabCloseChoiceSettingsStore
        self.sessionNotifier = sessionNotifier
        self.windowRegistry = windowRegistry
        self.titleAliases = ConversationTitleAliases.load(from: userDefaults)
        self.projectDisplayNames = ProjectDisplayNames.load(from: userDefaults)
        self.pinnedItems = PinnedItems.load(from: userDefaults)
        self.archivedSessions = ArchivedSessions.load(from: userDefaults)
        self.messageBookmarks = MessageBookmarks.load(from: userDefaults)
        self.sessionsDeletedWhenTabCloses = SessionsDeletedWhenTabCloses.load(from: userDefaults)
        self.sidebarProjectList = SidebarProjectList.load(from: userDefaults)
        self.remoteHostList = RemoteHostList.load(from: userDefaults)
        self.remoteHostsUsingTmuxPrefix = RemoteHostsUsingTmuxPrefix.load(from: userDefaults)
        self.disconnectedRemoteHosts = DisconnectedRemoteHosts.load(from: userDefaults)
        self.cliStartCommands = CLIStartCommands.load(from: userDefaults)
        self.remoteShellStartupChecks = RemoteShellStartupChecks.load(from: userDefaults)
        self.keptHostChecks = KeptHostChecks.load(from: userDefaults)
        applyRemoteShellStartups()
        sshHostsLoggedIn = SSHLoginConnections.shared.loggedInHosts
        LoginShellEnvironment.warmUpInBackground()
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
        windowRegistry.add(self)
    }

    deinit {
        thisMacRefreshTask?.cancel()
    }

    func cancelThisMacRefresh() {
        thisMacRefreshTask?.cancel()
        thisMacRefreshTask = nil
        isRefreshQueued = false
    }

    /// This window's scan of this Mac, or another window's, which a refresh asked for here would join (see
    /// `WorkspaceReadService`); either may have read the session folders before the change that prompted the refresh.
    var isThisMacScanUnderWay: Bool {
        isScanningThisMac || windowRegistry.stores.contains {
            $0 !== self && $0.readService === readService && $0.isScanningThisMac
        }
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
        thisMacRefreshTask = Task { [weak self, readService] in
            do {
                let result = try await readService.discoverThisMac()
                try Task.checkCancellation()
                guard let self else { return }
                self.thisMacRefreshTask = nil
                self.tmuxSessionNamesByHost[.thisMac] = Set(result.tmuxPaneProcessIDs.keys)
                self.thisMacTmuxPaneProcessIDs = result.tmuxPaneProcessIDs
                self.setInstalledProviders(result.installedProviders, on: .thisMac)
                self.replaceConversations(
                    on: .thisMac,
                    with: result.conversations,
                    discardMissingReopeningTabs: result.failures.isEmpty
                )
                self.linkWaitingTabsByAppearance(on: .thisMac)
                self.recoverLostKiroCLIs()
                self.hostRefreshStatuses[.thisMac] = result.failures.isEmpty
                    ? .refreshed(.now)
                    : .failed(result.failures.joined(separator: "\n"))
                if self.isRefreshQueued {
                    self.isRefreshQueued = false
                    self.refreshThisMac()
                } else {
                    Task { await self.discoverNewSessions(mayRefresh: false) }
                }
                self.startQueuedDeletion()
            } catch is CancellationError {
                self?.thisMacRefreshTask = nil
            } catch {
                guard let self else { return }
                self.thisMacRefreshTask = nil
                self.hostRefreshStatuses[.thisMac] = .failed(error.localizedDescription)
            }
        }
    }

    /// Swaps in what one host lists now, keeping every other host's sessions.
    func replaceConversations(on host: SessionHost, with hostConversations: [Conversation], discardMissingReopeningTabs: Bool = true) {
        let topLevelConversations = hostConversations.filter { !$0.isSubagent }
        rememberSidebarProjects(Set(topLevelConversations.map(\.projectDirectoryKey)))
        let updatedConversations = (conversations.filter { $0.host != host } + topLevelConversations)
            .sorted { $0.updatedAt > $1.updatedAt }
        let updatedSubagents = (subagentConversations.filter { $0.host != host } + hostConversations.filter(\.isSubagent))
            .sorted { $0.updatedAt > $1.updatedAt }
        if subagentConversations != updatedSubagents { subagentConversations = updatedSubagents }
        if conversations != updatedConversations { conversations = updatedConversations }
        synchronizeTerminalTitles()
        reopenWaitingTabs(on: host, discardMissingSessions: discardMissingReopeningTabs)
    }

    func adapter(for provider: ConversationProvider) -> (any ConversationAdapter)? {
        adapters.first { $0.provider == provider }
    }

    // MARK: - Titles, project names, pins, and bookmarks

    func title(for conversation: Conversation) -> String {
        titleAliases.title(for: conversation)
    }

    func applySuggestedTitle(_ title: String, toSessionID sessionID: String, provider: ConversationProvider, on host: SessionHost) {
        guard let index = conversations.firstIndex(where: { $0.provider == provider && $0.host == host && $0.sessionID == sessionID }),
              conversations[index].suggestedTitle != title else { return }
        conversations[index] = conversations[index].withSuggestedTitle(title)
    }

    func rename(_ conversation: Conversation, to proposedTitle: String) {
        changeSavedCustomization(\.titleAliases) { $0.rename(conversation, to: proposedTitle) }
        for store in storesSharingCustomizations { store.synchronizeTerminalTitles() }
    }

    func projectDisplayName(forProjectPath projectPath: String) -> String {
        projectDisplayNames.displayName(forProjectPath: projectPath)
    }

    func renameProject(_ projectPath: String, to proposedName: String) {
        changeSavedCustomization(\.projectDisplayNames) { $0.rename(projectPath: projectPath, to: proposedName) }
    }

    func setPinned(_ isPinned: Bool, projectPath: String) {
        changeSavedCustomization(\.pinnedItems) { $0.setPinned(isPinned, projectPath: projectPath) }
    }

    func setPinned(_ isPinned: Bool, conversation: Conversation) {
        changeSavedCustomization(\.pinnedItems) { $0.setPinned(isPinned, conversationID: conversation.id) }
    }

    /// Archiving only hides the sessions from the Projects list; files, open tabs, names, pins, and bookmarks are kept.
    func setArchived(_ isArchived: Bool, conversations: [Conversation]) {
        changeSavedCustomization(\.archivedSessions) { $0.setArchived(isArchived, conversationIDs: conversations.map(\.id)) }
    }

    /// Whether closing the sessions' tab deletes them; see `SessionsDeletedWhenTabCloses`.
    func setDeletedWhenTabCloses(_ isDeleted: Bool, conversationIDs: [String]) {
        changeSavedCustomization(\.sessionsDeletedWhenTabCloses) {
            $0.setDeletedWhenTabCloses(isDeleted, conversationIDs: conversationIDs)
        }
    }

    /// From a drag in the sidebar: pins the project if it is not pinned yet, at `placement` among the pinned ones.
    func movePinnedProject(_ projectPath: String, to placement: PinnedPlacement) {
        changeSavedCustomization(\.pinnedItems) { $0.movePinnedProject(projectPath, to: placement) }
    }

    /// From a drag in the sidebar: pins the session if it is not pinned yet, at `placement` among the pinned ones.
    func movePinnedConversation(_ conversationID: String, to placement: PinnedPlacement) {
        changeSavedCustomization(\.pinnedItems) { $0.movePinnedConversation(conversationID, to: placement) }
    }

    /// Adds a bookmark with the lowest free letter to the message, or removes the one it has. The letter is chosen from what
    /// is saved, so two windows never hand out the same one. Whether to add or remove follows what this window shows: a
    /// reading window whose workspace window closed hears of no other window's change, and must not remove a bookmark it
    /// doesn't show. Nil for an entry that is neither your message nor a reply.
    @discardableResult
    func toggleMessageBookmark(on entry: TranscriptEntry, in conversation: Conversation) -> MessageBookmarkToggle? {
        guard let kind = MessageBookmark.Kind(entry.content) else { return nil }
        let shown = messageBookmarks.bookmarks(forConversationID: conversation.id).first { $0.entryID == entry.id }
        let snippet = MessageBookmarkNavigation.snippet(of: entry) ?? ""
        var toggle = MessageBookmarkToggle.allLettersInUse
        changeSavedCustomization(\.messageBookmarks) { bookmarks in
            let saved = bookmarks.bookmarks(forConversationID: conversation.id).first { $0.entryID == entry.id }
            switch (shown, saved) {
            case (nil, let saved?): toggle = .added(saved)   // another window added it
            case (let shown?, nil): toggle = .removed(shown)   // another window removed it
            default: toggle = bookmarks.toggle(entryID: entry.id, kind: kind, snippet: snippet, conversationID: conversation.id)
            }
        }
        return toggle
    }

    func removeMessageBookmark(_ bookmark: MessageBookmark, in conversation: Conversation) {
        changeSavedCustomization(\.messageBookmarks) { $0.remove(bookmark, conversationID: conversation.id) }
    }

    func removeAllMessageBookmarks(in conversation: Conversation) {
        changeSavedCustomization(\.messageBookmarks) { $0.removeAll(forConversationIDs: [conversation.id]) }
    }

    func updateMessageBookmark(_ bookmark: MessageBookmark, entryID: Int, snippet: String, in conversation: Conversation) {
        changeSavedCustomization(\.messageBookmarks) { $0.update(bookmark, entryID: entryID, snippet: snippet, conversationID: conversation.id) }
    }

    /// The message's bookmark, adding one when it has none, for Edit Bookmark… (⇧⌘D). Nil for an entry that is
    /// neither your message nor a reply.
    func ensureMessageBookmark(on entry: TranscriptEntry, in conversation: Conversation) -> MessageBookmarkEnsuring? {
        guard let kind = MessageBookmark.Kind(entry.content) else { return nil }
        let snippet = MessageBookmarkNavigation.snippet(of: entry) ?? ""
        var ensuring = MessageBookmarkEnsuring.allLettersInUse
        changeSavedCustomization(\.messageBookmarks) {
            ensuring = $0.ensure(entryID: entry.id, kind: kind, snippet: snippet, conversationID: conversation.id)
        }
        return ensuring
    }

    /// Saves a bookmark's label and tags; nil when another window removed the bookmark meanwhile (RDR-51).
    @discardableResult
    func setMessageBookmarkDetails(of bookmark: MessageBookmark, label: String?, tags: [String],
                                   in conversation: Conversation) -> MessageBookmark? {
        var saved: MessageBookmark?
        changeSavedCustomization(\.messageBookmarks) {
            saved = $0.setDetails(of: bookmark, label: label, tags: tags, conversationID: conversation.id)
        }
        return saved
    }

    /// Changes a name, pin, archiving, bookmark, or deletion when a tab closes, which every workspace window shares.
    /// The change starts from what is saved, not from this window's copy: another window may have changed it since
    /// this one loaded it, and saving this window's copy lost that change. Every window then shows the result.
    private func changeSavedCustomization<Customization: SavedCustomization>(
        _ customization: ReferenceWritableKeyPath<ConversationStore, Customization>,
        _ change: (inout Customization) -> Void
    ) {
        let saved = Customization.load(from: userDefaults)
        var updated = saved
        change(&updated)
        if updated != saved { updated.save(to: userDefaults) }
        for store in storesSharingCustomizations where store[keyPath: customization] != updated {
            store[keyPath: customization] = updated
        }
    }

    /// This window's store and the other windows' that keep their settings in the same place.
    private var storesSharingCustomizations: [ConversationStore] {
        [self] + windowRegistry.stores.filter { $0 !== self && $0.userDefaults === userDefaults }
    }

    // MARK: - Deletion

    /// A tab in any window, or a CLI still running in tmux on the session's host.
    func hasTerminal(for conversation: Conversation) -> Bool {
        terminalSessions.contains { $0.conversation?.id == conversation.id }
            || hasTerminalInAnotherWindow(for: conversation)
            || isRunningInTmux(conversation)
    }

    var isDeletingSessions: Bool {
        !pendingDeletionConversationIDs.isEmpty
    }

    /// One session has nothing to cancel between, so only a deletion of several shows the sidebar's progress bar.
    var isDeletingSeveralSessions: Bool {
        pendingDeletionConversationIDs.count > 1
    }

    func isDeleting(on host: SessionHost) -> Bool {
        hostsWithRunningDeletion.contains(host)
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

    /// A project's sessions are deleted as Close and delete does: those that run have their CLIs ended first.
    func deletionPlan(forProjects projectPaths: Set<String>) -> SessionDeletionPlan {
        deletionPlan(for: conversations.filter { projectPaths.contains($0.projectDirectoryKey) }, endingTheirCLIs: true)
    }

    /// Sessions already being deleted, or waiting to be, are left out: they are not deleted twice. So are subagents'
    /// sessions, which go only with the session that started them. With `endingTheirCLIs`, as for Close and delete,
    /// sessions with a tab or a CLI in tmux are deletable too.
    func deletionPlan(for candidateConversations: [Conversation], endingTheirCLIs: Bool = false) -> SessionDeletionPlan {
        let notYetPending = candidateConversations.filter { !$0.isSubagent && !isDeletionPending(for: $0) }
        let deletable = endingTheirCLIs ? notYetPending : notYetPending.filter { !hasTerminal(for: $0) }
        let deletesSubagents = Dictionary(grouping: deletable, by: \.provider.deletesSubagentsWithSession)
        return SessionDeletionPlan(
            deletableConversations: deletable,
            openTerminalCount: notYetPending.count - deletable.count,
            cliEndingCount: endingTheirCLIs ? deletable.filter(hasTerminal(for:)).count : 0,
            deletedSubagentCount: (deletesSubagents[true] ?? []).reduce(0) { $0 + descendantSubagentCount(of: $1) },
            keptSubagentCount: (deletesSubagents[false] ?? []).reduce(0) { $0 + descendantSubagentCount(of: $1) }
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
        closeAndDeleteConversations(conversations.filter { $0.projectDirectoryKey == projectPath })
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
        // Deleting on a disconnected host connects it; its sessions then wait for the refresh that starts.
        for host in Set(deletableConversations.map(\.host)) { connectIfDisconnected(host) }
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

    /// Takes the deleted sessions off the list in one change, and forgets their custom titles, pins, archiving,
    /// deletion when their tab closes, and bookmarks, with the bookmarks of the subagents' sessions deleted with them.
    private func removeDeletedConversations(_ deleted: [Conversation]) {
        guard !deleted.isEmpty else { return }
        let deletedIDs = Set(deleted.map(\.id))
        // Some CLIs delete a session's subagents' sessions with it; Antigravity's stay as conversations of their own.
        let deletedSubagentIDs = Set(deleted.filter(\.provider.deletesSubagentsWithSession).flatMap { descendantSubagents(of: $0).map(\.id) })
        conversations.removeAll { deletedIDs.contains($0.id) }
        // Gone at once, as their sessions are, rather than at the next refresh; a reading window left open on one then
        // keeps no bookmarks (`SessionReadingView`).
        let keptSubagents = subagentConversations.filter { !deletedIDs.contains($0.id) && !deletedSubagentIDs.contains($0.id) }
        if keptSubagents.count != subagentConversations.count { subagentConversations = keptSubagents }

        changeSavedCustomization(\.titleAliases) { aliases in
            for conversationID in deletedIDs { aliases.removeTitle(forConversationID: conversationID) }
        }
        changeSavedCustomization(\.pinnedItems) { pins in
            for conversationID in deletedIDs { pins.setPinned(false, conversationID: conversationID) }
        }
        changeSavedCustomization(\.archivedSessions) { $0.setArchived(false, conversationIDs: deletedIDs) }
        changeSavedCustomization(\.messageBookmarks) { $0.removeAll(forConversationIDs: deletedIDs.union(deletedSubagentIDs)) }
        changeSavedCustomization(\.sessionsDeletedWhenTabCloses) {
            $0.setDeletedWhenTabCloses(false, conversationIDs: deletedIDs)
        }
    }

    // MARK: - Tabs

    /// Tells views that look at tabs through the store that a tab's own state changed; the store does not see it.
    func noteTabStateChanged() {
        tabStateRevision &+= 1
    }

    /// Counts every open tab's own changes in `tabStateRevision`, as views reading tabs through the store see a tab's
    /// state, such as its CLI's activity or whether it ended, without observing the tab. A tab sets each of its
    /// properties only when its value changes, so selecting a tab, which changes none, redraws nothing more.
    private func followTabStateChanges() {
        let openTabIDs = Set(terminalSessionsStorage.map(\.id))
        tabStateSubscriptions = tabStateSubscriptions.filter { openTabIDs.contains($0.key) }
        for tab in terminalSessionsStorage where tabStateSubscriptions[tab.id] == nil {
            tabStateSubscriptions[tab.id] = [
                tab.objectWillChange.sink { [weak self] _ in self?.noteTabStateChanged() },
                // Not a tab that had ended before it came here, as from another window.
                tab.$hasExited.dropFirst().filter { $0 }.sink { [weak self, weak tab] _ in
                    guard let tab else { return }
                    self?.noteCLIEnded(in: tab)
                },
            ]
        }
    }

    /// Swaps a tab for another in the same place, closing the old one; keeps it selected if it was, and hands it the
    /// old tab's place in a split.
    func replaceTerminal(at index: Int, with session: TerminalSession) {
        defer { persistOpenTabs() }
        let replacedID = terminalSessions[index].id
        let splitChooserWasSelected = selectedTerminalID == replacedID && selectsShownSplitChooser
        terminalSessions[index].close()
        followLightDarkChanges(of: session)
        // Before the old tab goes, which would close its chooser.
        if let chooserIndex = terminalSplitChoosers.firstIndex(where: { $0.tabID == replacedID }) {
            terminalSplitChoosers[chooserIndex].tabID = session.id
        }
        terminalSessions[index] = session
        if terminalSplits.contains(where: { $0.contains(replacedID) }) {
            terminalSplits = terminalSplits.map { $0.replacing(replacedID, with: session.id) }
        }
        if selectedTerminalID == replacedID { selectedTerminalID = session.id }
        if splitChooserWasSelected { selectsShownSplitChooser = true }
    }

    /// Adds the tab after the last tab of its project's group, which may be a split's, or at the end, and shows it. A tab
    /// started from a split chooser's New Session… takes the chooser's place instead.
    func openTerminal(_ session: TerminalSession) {
        defer { persistOpenTabs() }
        showProjectInSidebar(session.projectDirectoryKey)
        followLightDarkChanges(of: session)
        terminalSessions.insert(session, at: tabStrip.insertionIndex(forNewTabOfProject: session.projectDirectoryKey))
        selectedTerminalID = session.id
        if let chooserID = splitChooserAwaitingNewTab {
            splitChooserAwaitingNewTab = nil
            chooseTab(session.id, inSplitChooser: chooserID)
        }
    }

    /// Puts a tab reopened from the last quit at `index` without showing it, unless `selecting`. Where a tab at
    /// `index` would part a split's two tabs or sit among another group's tabs, it goes where a new tab of its
    /// project opens instead.
    func insertReopenedTerminal(_ session: TerminalSession, at index: Int, selecting: Bool) {
        defer { persistOpenTabs() }
        showProjectInSidebar(session.projectDirectoryKey)
        let index = tabStrip.insertionIndex(forReopenedTabOfProject: session.projectDirectoryKey, at: index)
        followLightDarkChanges(of: session)
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

    /// Takes on the strip's order and splits, changing only what differs. `incomingTabs` are tabs the strip has that
    /// come from another window.
    func apply(_ strip: TerminalTabStrip, bringingIn incomingTabs: [TerminalSession] = []) {
        let tabIDs = strip.tabIDs
        if tabIDs != terminalSessions.map(\.id) {
            let tabsByID = Dictionary(uniqueKeysWithValues: (terminalSessions + incomingTabs).map { ($0.id, $0) })
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

    /// The tab group the tab shows in: its project's, by its key, or its split's while it is in one, which for a split
    /// across projects is a group of the split's own, see `TerminalSplit.groupKey`. Tabs of one group always sit
    /// together in `terminalSessions`.
    func tabGroupKey(of tab: TerminalSession) -> String {
        split(containing: tab.id)?.groupKey ?? tab.projectDirectoryKey
    }

    /// Every tab's group key, in tab bar order.
    var tabGroupKeys: [String] {
        terminalSessions.map(tabGroupKey(of:))
    }

    /// Every open tab's project, each once, in tab bar order: the projects the groups are named for, and those of the
    /// tabs of splits across projects, whose colors are their projects' too.
    var tabProjectKeysInOrder: [String] {
        var projectKeys: [String] = []
        for tab in terminalSessions where !projectKeys.contains(tab.projectDirectoryKey) {
            projectKeys.append(tab.projectDirectoryKey)
        }
        return projectKeys
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
    /// `TerminalTabStrip.addSplit(joining:beside:on:splitID:)` for where the other tab moves. Neither tab may be in a
    /// split, or beside a split chooser, already. A reopened tab still waiting to be shown starts as it joins. The other
    /// tab joins on `side`, or on the side it came from without one, in a split laid out as `orientation`.
    func splitSelectedTerminal(
        with id: UUID,
        on side: TerminalSplit.Side? = nil,
        orientation: TerminalSplit.Orientation = .sideBySide
    ) {
        guard let selectedTerminalID, let joiningTab = terminalSessions.first(where: { $0.id == id }),
              splitChooser(beside: id) == nil, splitChooser(beside: selectedTerminalID) == nil else { return }
        var strip = tabStrip
        guard let split = strip.addSplit(joining: id, beside: selectedTerminalID, on: side) else { return }
        defer { persistOpenTabs() }
        if orientation == .stacked { stackedSplitViewIDs.insert(split.id) }
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
              let incomingTab = terminalSessions.first(where: { $0.id == tabID }),
              splitChooser(beside: tabID) == nil else { return }
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

    /// Closes the split choosers of tabs that closed or joined a split, and forgets when closed tabs were selected.
    private func forgetClosedTabsInSplitChoosers() {
        let openTabIDs = Set(terminalSessionsStorage.map(\.id))
        let keptChoosers = terminalSplitChoosers.filter { chooser in
            openTabIDs.contains(chooser.tabID) && !terminalSplits.contains { $0.contains(chooser.tabID) }
        }
        if keptChoosers != terminalSplitChoosers { terminalSplitChoosers = keptChoosers }
        if tabIDsByLastSelected.contains(where: { !openTabIDs.contains($0) }) {
            tabIDsByLastSelected.removeAll { !openTabIDs.contains($0) }
        }
    }

    /// The tabs whose terminals are on screen: both tabs of a shown split, or else the selected tab.
    var terminalIDsOnScreen: Set<UUID> {
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
    /// Moving between the two panes of a shown split keeps both on screen, so it refreshes nothing. Selecting the tab
    /// beside the shown split chooser gives that tab the keyboard back.
    func selectTerminal(_ id: UUID?) {
        guard selectedTerminalID != id else {
            selectsShownSplitChooser = false
            return
        }
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
        rememberClosedTab(closedTab, at: index)
        closedTab.close()
        apply(strip)
        if selectedTerminalID == id { selectedTerminalID = tabToSelect }
        if closedTab.startsNewSession { refresh(closedTab.host) }
    }

    func closeAllTerminals() {
        defer { persistOpenTabs() }
        for session in terminalSessions { session.close() }
        terminalSplitChoosers = []
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
