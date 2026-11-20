import Combine
import Foundation
import Observation

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
    private(set) var subagentConversations: [Conversation] = [] {
        didSet { subagentIndex = SubagentConversationIndex(subagentConversations) }
    }
    private(set) var subagentIndex = SubagentConversationIndex([])
    private(set) var conversationsRevision = 0
    @ObservationIgnored var cachedSidebarProjection: SidebarProjection?
    @ObservationIgnored var cachedFilteredSidebarProjection: FilteredSidebarProjection?
    var messageIndexer: SessionMessageIndexer { readService.messageIndexer }
    private(set) var alert: StoreAlert?
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
    private(set) var hiddenConversationProviders: HiddenConversationProviders
    var sidebarProjectList: SidebarProjectList
    private var terminalSessionsStorage: [TerminalSession] = [] {
        didSet {
            windowRegistry.tabsChanged(in: self)
            followTabStateChanges()
            closeSplitChoosersOfTabsThatClosedOrJoinedASplit()
            forgetWhenClosedTabsWereSelected()
        }
    }
    @ObservationIgnored private var tabStateSubscriptions: [UUID: [AnyCancellable]] = [:]
    private(set) var terminalSessions: [TerminalSession] {
        get {
            makeTabReadersObserveEachTabsOwnState()
            return terminalSessionsStorage
        }
        set { terminalSessionsStorage = newValue }
    }
    private(set) var tabStateRevision = 0
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
    private(set) var terminalSplits: [TerminalSplit] = [] {
        didSet {
            markTerminalsOnScreenSeen()
            closeSplitChoosersOfTabsThatClosedOrJoinedASplit()
            forgetWhenClosedTabsWereSelected()
        }
    }
    var terminalSplitChoosers: [TerminalSplitChooser] = [] {
        didSet {
            if shownSplitChooser == nil { selectsShownSplitChooser = false }
        }
    }
    var selectsShownSplitChooser = false
    private(set) var tabIDsByLastSelected: [UUID] = []
    @ObservationIgnored var splitChooserAwaitingNewTab: UUID?
    private(set) var pendingDeletionConversationIDs: Set<String> = []
    private(set) var queuedDeletionConversationIDs: Set<String> = []
    let deletionProgress = SessionDeletionProgress()
    var remoteHostList: RemoteHostList
    var remoteHostsUsingTmuxPrefix: RemoteHostsUsingTmuxPrefix
    var disconnectedRemoteHosts: DisconnectedRemoteHosts
    var hostDisconnectQuestion: HostDisconnectQuestion?
    @ObservationIgnored var remoteSessionDiscovery = RemoteSessionDiscovery()
    var cliStartCommands: CLIStartCommands
    var remoteShellStartupChecks: RemoteShellStartupChecks
    var hostsCheckingShellStartup: Set<String> = []
    var hostsRecheckedShellStartup: Set<String> = []
    var hostCheck: HostCheckSheetState?
    var keptHostChecks: KeptHostChecks
    var tmuxServerProblemsByHost: [String: String] = [:]
    @ObservationIgnored var hostsAskingForBackgroundCheck: Set<String> = []
    var hostRefreshStatuses: [SessionHost: HostRefreshStatus] = [:]
    @ObservationIgnored var remoteHostCopies = RemoteHostCopies()
    var sshHostsNeedingLogIn: Set<String> = []
    var sshHostsLoggingIn: Set<String> = []
    var sshHostsLoggedIn: Set<String> = []
    var remoteSessionCopySteps: [SessionHost: RemoteSessionCopyStep] = [:]
    var tmuxSessionNamesByHost: [SessionHost: Set<String>] = [:]
    var installedProvidersByHost: [SessionHost: Set<ConversationProvider>] = [:]
    var detachedCLIActivities: [String: CLIActivity] = [:]
    @ObservationIgnored var remoteDetachedActivityReader = RemoteDetachedActivityReader.shared
    @ObservationIgnored var remoteDetachedSince: [RemoteTmuxSessionKey: Date] = [:]
    var thisMacTmuxPaneProcessIDs: [String: Int32] = [:]
    let tmuxCommandQueues = TmuxCommandQueues()
    let codexTurnTracker = CodexRolloutTurnTracker()
    var codexWaitReader = CodexAppServerWaitReader.forThisApp()
    var sessionAttentionTracker = SessionAttentionTracker()
    var unseenFinishedTurns = UnseenFinishedTurns()
    var waitingForYouStartTimes = WaitingForYouStartTimes()
    var pendingTabReopening = PendingTabReopening()
    let tabPersistenceWindowID = UUID()
    var openTabPersistence: OpenTabPersistence?
    var isSavingOpenTabsOnceAfterChanges = false
    var isTearingDownWorkspace = false
    var recentlyClosedTabs = RecentlyClosedTabs()
    var isClosingTabsWithoutRemembering = false
    let sessionNotifier: any SessionNotifying
    let windowRegistry: WorkspaceWindowRegistry
    private(set) var lastRefreshStartedAt: Date?
    private var isRefreshQueued = false
    private var hostsWithRunningDeletion: Set<SessionHost> = []
    private var hostsToRefreshAfterDeletion: Set<SessionHost> = []
    private var sessionsJoiningRunningDeletion: [Conversation] = []
    private var finishedDeletionRounds: SessionDeletionReport?
    private var deletionTask: Task<Void, Never>?
    @ObservationIgnored private var deletionCancellation = SessionDeletionCancellation()
    @ObservationIgnored private var thisMacRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var thisMacRefreshGeneration = UUID()
    @ObservationIgnored let remoteHostWork = RemoteHostWork()
    var deletionListUpdateInterval: Duration = .milliseconds(500)

    private let readService: WorkspaceReadService
    private let adapters: [any ConversationAdapter]
    let commandResolver: NativeCLICommandResolver
    private let remoteDeletion: RemoteConversationDeletion
    let remoteClaudeSessionIDFlagSupport: RemoteClaudeSessionIDFlagSupport
    let remoteShellStartupCheck: RemoteShellStartupCheck
    let remoteHostCheck: RemoteHostCheck
    let userDefaults: UserDefaults
    let terminalEngineStore: TerminalEngineStore
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
        self.hiddenConversationProviders = HiddenConversationProviders.load(from: userDefaults)
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
        thisMacRefreshGeneration = UUID()
        thisMacRefreshTask?.cancel()
        thisMacRefreshTask = nil
        isRefreshQueued = false
        hostRefreshStatuses.removeValue(forKey: .thisMac)
    }

    var isThisMacScanUnderWay: Bool {
        isScanningThisMac
            || windowRegistry.stores.contains {
                $0 !== self && $0.readService === readService && $0.isScanningThisMac
            }
    }

    func refreshThisMac() {
        guard !deferRefreshWhileDeleting(on: .thisMac) else { return }
        guard !isScanningThisMac else {
            isRefreshQueued = true
            return
        }
        hostRefreshStatuses[.thisMac] = .refreshing
        lastRefreshStartedAt = .now
        let generation = UUID()
        thisMacRefreshGeneration = generation
        let hostWork = windowRegistry.hostSessionWork
        thisMacRefreshTask = Task { [weak self, readService, hostWork] in
            do {
                let result = try await readService.discoverThisMac(coordinatingWith: hostWork)
                try Task.checkCancellation()
                guard let self, self.thisMacRefreshGeneration == generation else { return }
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
                self.hostRefreshStatuses[.thisMac] =
                    result.failures.isEmpty
                    ? .refreshed(.now)
                    : .failed(result.failures.joined(separator: "\n"))
                if self.isRefreshQueued {
                    self.isRefreshQueued = false
                    self.refreshThisMac()
                } else {
                    Task { await self.discoverNewSessions(mayRefresh: false) }
                }
                self.resumeQueuedHostWorkInAllWindows()
            } catch is CancellationError {
                guard let self, self.thisMacRefreshGeneration == generation else { return }
                self.thisMacRefreshTask = nil
                self.hostRefreshStatuses.removeValue(forKey: .thisMac)
                self.resumeQueuedHostWorkInAllWindows()
            } catch {
                guard let self, self.thisMacRefreshGeneration == generation else { return }
                self.thisMacRefreshTask = nil
                self.hostRefreshStatuses[.thisMac] = .failed(error.localizedDescription)
                self.resumeQueuedHostWorkInAllWindows()
            }
        }
    }

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

    func title(for conversation: Conversation) -> String {
        titleAliases.title(for: conversation)
    }

    func applySuggestedTitle(_ title: String, toSessionID sessionID: String, provider: ConversationProvider, on host: SessionHost) {
        guard let index = conversations.firstIndex(where: { $0.provider == provider && $0.host == host && $0.sessionID == sessionID }),
            conversations[index].suggestedTitle != title
        else { return }
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

    func setArchived(_ isArchived: Bool, conversations: [Conversation]) {
        changeSavedCustomization(\.archivedSessions) { $0.setArchived(isArchived, conversationIDs: conversations.map(\.id)) }
    }

    func setHidden(_ isHidden: Bool, provider: ConversationProvider) {
        changeSavedCustomization(\.hiddenConversationProviders) { $0.setHidden(isHidden, provider: provider) }
    }

    func setDeletedWhenTabCloses(_ isDeleted: Bool, conversationIDs: [String]) {
        changeSavedCustomization(\.sessionsDeletedWhenTabCloses) {
            $0.setDeletedWhenTabCloses(isDeleted, conversationIDs: conversationIDs)
        }
    }

    func movePinnedProject(_ projectPath: String, to placement: PinnedPlacement) {
        changeSavedCustomization(\.pinnedItems) { $0.movePinnedProject(projectPath, to: placement) }
    }

    func movePinnedConversation(_ conversationID: String, to placement: PinnedPlacement) {
        changeSavedCustomization(\.pinnedItems) { $0.movePinnedConversation(conversationID, to: placement) }
    }

    @discardableResult
    func toggleMessageBookmark(on entry: TranscriptEntry, in conversation: Conversation) -> MessageBookmarkToggle? {
        guard let message = BookmarkableMessage(entry) else { return nil }
        return toggleMessageBookmark(on: message, in: conversation)
    }

    @discardableResult
    func toggleMessageBookmark(on message: BookmarkableMessage, in conversation: Conversation) -> MessageBookmarkToggle {
        let entry = message.entry
        let shown = messageBookmarks.bookmarks(forConversationID: conversation.id).first { $0.entryID == entry.id }
        let snippet = MessageBookmarkNavigation.snippet(of: entry) ?? ""
        var toggle = MessageBookmarkToggle.allLettersInUse
        changeSavedCustomization(\.messageBookmarks) { bookmarks in
            let saved = bookmarks.bookmarks(forConversationID: conversation.id).first { $0.entryID == entry.id }
            switch (shown, saved) {
            case (nil, let saved?): toggle = .added(saved)
            case (let shown?, nil): toggle = .removed(shown)
            default: toggle = bookmarks.toggle(entryID: entry.id, kind: message.kind, snippet: snippet, conversationID: conversation.id)
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
        changeSavedCustomization(\.messageBookmarks) {
            $0.update(bookmark, entryID: entryID, snippet: snippet, conversationID: conversation.id)
        }
    }

    func ensureMessageBookmark(on entry: TranscriptEntry, in conversation: Conversation) -> MessageBookmarkEnsuring? {
        guard let message = BookmarkableMessage(entry) else { return nil }
        return ensureMessageBookmark(on: message, in: conversation)
    }

    func ensureMessageBookmark(on message: BookmarkableMessage, in conversation: Conversation) -> MessageBookmarkEnsuring {
        let entry = message.entry
        let snippet = MessageBookmarkNavigation.snippet(of: entry) ?? ""
        var ensuring = MessageBookmarkEnsuring.allLettersInUse
        changeSavedCustomization(\.messageBookmarks) {
            ensuring = $0.ensure(entryID: entry.id, kind: message.kind, snippet: snippet, conversationID: conversation.id)
        }
        return ensuring
    }

    @discardableResult
    func setMessageBookmarkDetails(
        of bookmark: MessageBookmark, label: String?, tags: [String],
        in conversation: Conversation
    ) -> MessageBookmark? {
        var saved: MessageBookmark?
        changeSavedCustomization(\.messageBookmarks) {
            saved = $0.setDetails(of: bookmark, label: label, tags: tags, conversationID: conversation.id)
        }
        return saved
    }

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

    private var storesSharingCustomizations: [ConversationStore] {
        [self] + windowRegistry.stores.filter { $0 !== self && $0.userDefaults === userDefaults }
    }

    func hasTerminal(for conversation: Conversation) -> Bool {
        terminalSessions.contains { $0.conversation?.id == conversation.id }
            || hasTerminalInAnotherWindow(for: conversation)
            || isRunningInTmux(conversation)
    }

    var isDeletingSessions: Bool {
        !pendingDeletionConversationIDs.isEmpty
    }

    var isDeletingSeveralSessions: Bool {
        pendingDeletionConversationIDs.count > 1
    }

    func isDeleting(on host: SessionHost) -> Bool {
        storesSharingHostWork.contains { $0.hostsWithRunningDeletion.contains(host) }
    }

    func deferRefreshWhileDeleting(on host: SessionHost) -> Bool {
        guard isDeleting(on: host) else { return false }
        hostsToRefreshAfterDeletion.insert(host)
        return true
    }

    func isDeletionPending(for conversation: Conversation) -> Bool {
        storesSharingHostWork.contains {
            $0.pendingDeletionConversationIDs.contains(conversation.id) || $0.queuedDeletionConversationIDs.contains(conversation.id)
        }
    }

    var storesSharingHostWork: [ConversationStore] {
        [self] + windowRegistry.storesWithSessionWork.filter { $0 !== self }
    }

    func resumeQueuedHostWorkInAllWindows() {
        let stores = storesSharingHostWork.filter { !$0.isTearingDownWorkspace }
        for store in stores { store.startQueuedDeletion() }
        for store in stores {
            let ready = store.hostsToRefreshAfterDeletion.filter { !store.isDeleting(on: $0) }
            store.hostsToRefreshAfterDeletion.subtract(ready)
            for host in store.hosts where ready.contains(host) { store.refresh(host) }
        }
    }

    func deletionPlan(for projectPath: String) -> SessionDeletionPlan {
        deletionPlan(forProjects: [projectPath])
    }

    func deletionPlan(forProjects projectPaths: Set<String>) -> SessionDeletionPlan {
        deletionPlan(for: conversations.filter { projectPaths.contains($0.projectDirectoryKey) }, endingTheirCLIs: true)
    }

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
            show(
                StoreAlert(
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

    func deleteConversations(_ candidateConversations: [Conversation]) {
        let candidateIDs = Set(candidateConversations.map(\.id))
        let deletionPlan = deletionPlan(for: conversations.filter { candidateIDs.contains($0.id) })
        startOrQueueDeletion(of: deletionPlan.deletableConversations)
    }

    func retryDeletion(of conversationIDs: Set<String>) {
        deleteConversations(conversations.filter { conversationIDs.contains($0.id) })
    }

    func startQueuedDeletion() {
        guard !queuedDeletionConversationIDs.isEmpty else { return }
        let conversationIDs = queuedDeletionConversationIDs
        queuedDeletionConversationIDs = []
        retryDeletion(of: conversationIDs)
    }

    func cancelDeletion() {
        guard let deletionTask, !deletionProgress.isStopping else { return }
        deletionProgress.markStopping()
        deletionTask.cancel()
    }

    func discardQueuedDeletions(on host: SessionHost) {
        let ids = Set(conversations.filter { $0.host == host }.map(\.id))
        queuedDeletionConversationIDs.subtract(ids)
        deletionCancellation.cancel(on: host)
    }

    private func startOrQueueDeletion(of deletableConversations: [Conversation]) {
        guard !deletableConversations.isEmpty else { return }
        for host in Set(deletableConversations.map(\.host)) { connectIfDisconnected(host) }
        let hosts = Set(deletableConversations.map(\.host))
        let isHostRefreshing = storesSharingHostWork.contains { store in
            hosts.contains { store.hostRefreshStatuses[$0] == .refreshing }
        }
        let anotherWindowDeletes = storesSharingHostWork.contains {
            $0 !== self && !$0.hostsWithRunningDeletion.isDisjoint(with: hosts)
        }
        let cancelledHostInRunningBatch = isDeletingSessions && hosts.contains { deletionCancellation.isCancelled(on: $0) }
        if isHostRefreshing || anotherWindowDeletes || deletionProgress.isStopping || cancelledHostInRunningBatch {
            queuedDeletionConversationIDs.formUnion(deletableConversations.map(\.id))
        } else if isDeletingSessions {
            joinRunningDeletion(deletableConversations)
        } else {
            deletionCancellation = SessionDeletionCancellation()
            pendingDeletionConversationIDs = Set(deletableConversations.map(\.id))
            hostsWithRunningDeletion = Set(deletableConversations.map(\.host))
            deletionProgress.start(totalCount: deletableConversations.count)
            windowRegistry.deletionStarted(in: self)
            deleteRoundInBackground(deletableConversations)
        }
    }

    private func joinRunningDeletion(_ deletableConversations: [Conversation]) {
        sessionsJoiningRunningDeletion += deletableConversations
        pendingDeletionConversationIDs.formUnion(deletableConversations.map(\.id))
        hostsWithRunningDeletion.formUnion(deletableConversations.map(\.host))
        deletionProgress.add(sessionCount: deletableConversations.count)
    }

    private func deleteRoundInBackground(_ deletableConversations: [Conversation]) {
        let adapters = self.adapters
        let remoteDeletion = self.remoteDeletion
        let listUpdateInterval = deletionListUpdateInterval
        let completedCountBeforeRound = deletionProgress.completedCount
        let unresponsiveHostsBeforeRound = finishedDeletionRounds?.unresponsiveHosts ?? [:]
        let hostWork = windowRegistry.hostSessionWork
        let cancellation = deletionCancellation
        deletionTask = Task.detached(priority: .userInitiated) {
            do {
                try await hostWork.withAccess(to: Set(deletableConversations.map(\.host))) {
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
                        if Task.isCancelled {
                            wasCanceled = true
                            break
                        }
                        if cancellation.isCancelled(on: conversation.host) {
                            wasCanceled = true
                            continue
                        }
                        attemptedCount += 1
                        if let unresponsiveHost = conversation.host.sshDestination.flatMap({ unresponsiveHosts[$0] }) {
                            failures.append(
                                ConversationDeletionFailure(
                                    conversation: conversation,
                                    reason: RemoteConversationDeletionError.notAttempted(unresponsiveHost).localizedDescription,
                                    unresponsiveHost: unresponsiveHost
                                ))
                        } else if let adapter = adapters.first(where: { $0.provider == conversation.provider }) {
                            do {
                                try Self.deleteFromDisk(
                                    conversation, adapter: adapter, remoteDeletion: remoteDeletion, claudeIndexBatch: claudeIndexBatch)
                                deletedSinceListUpdate.append(conversation)
                            } catch ConversationDeletionError.missingSource {
                                deletedSinceListUpdate.append(conversation)
                            } catch {
                                let unresponsiveHost = (error as? RemoteConversationDeletionError)?.unresponsiveHost
                                if let unresponsiveHost { unresponsiveHosts[unresponsiveHost.host] = unresponsiveHost }
                                let isFileGone = !FileManager.default.fileExists(atPath: conversation.sourceFile.path)
                                failures.append(
                                    ConversationDeletionFailure(
                                        conversation: conversation,
                                        reason: error.localizedDescription,
                                        unresponsiveHost: unresponsiveHost,
                                        isStillListed: !isFileGone
                                    ))
                                if isFileGone { deletedSinceListUpdate.append(conversation) }
                            }
                        }
                        if clock.now - lastListUpdate >= listUpdateInterval
                            || claudeIndexBatch.pendingCount >= ClaudeDeletionIndexBatch.maximumSessionCount
                        {
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
            } catch {
                await self.finishDeletionRound(
                    removing: [],
                    report: SessionDeletionReport(
                        requestedCount: deletableConversations.count, deletedCount: 0, failures: [], wasCanceled: true
                    ))
            }
        }
    }

    nonisolated private static func deleteFromDisk(
        _ conversation: Conversation,
        adapter: any ConversationAdapter,
        remoteDeletion: RemoteConversationDeletion,
        claudeIndexBatch: ClaudeDeletionIndexBatch
    ) throws {
        switch conversation.host {
        case .thisMac:
            if let claude = adapter as? ClaudeAdapter {
                try ClaudeConversationDeletion(configurationDirectory: claude.configurationDirectory, indexBatch: claudeIndexBatch).delete(
                    conversation)
            } else {
                try adapter.delete(conversation)
            }
        case .ssh: try remoteDeletion.delete(conversation)
        }
    }

    private func applyDeletionProgress(removing deleted: [Conversation], completedCount: Int) {
        removeDeletedConversations(deleted)
        deletionProgress.update(completedCount: completedCount)
    }

    private func finishDeletionRound(removing deleted: [Conversation], report roundReport: SessionDeletionReport) {
        var report = finishedDeletionRounds.map { $0.followed(by: roundReport) } ?? roundReport
        let joinedSessions = sessionsJoiningRunningDeletion
        sessionsJoiningRunningDeletion = []
        guard !joinedSessions.isEmpty else {
            finishDeletion(removing: deleted, report: report)
            return
        }
        guard !deletionProgress.isStopping else {
            report = report.followed(
                by: SessionDeletionReport(
                    requestedCount: joinedSessions.count, deletedCount: 0, failures: [], wasCanceled: true
                ))
            finishDeletion(removing: deleted, report: report)
            return
        }
        applyDeletionProgress(removing: deleted, completedCount: report.requestedCount)
        finishedDeletionRounds = report
        deleteRoundInBackground(joinedSessions)
    }

    private func finishDeletion(removing deleted: [Conversation], report: SessionDeletionReport) {
        let reportAlert = report.alert(titleOf: title(for:))
        removeDeletedConversations(deleted)
        pendingDeletionConversationIDs = []
        finishedDeletionRounds = nil
        deletionTask = nil
        deletionProgress.finish()
        if let reportAlert { show(reportAlert) }

        hostsWithRunningDeletion = []
        windowRegistry.deletionFinished(in: self)
        resumeQueuedHostWorkInAllWindows()
    }

    private func removeDeletedConversations(_ deleted: [Conversation], sharingWithOtherWindows: Bool = true) {
        guard !deleted.isEmpty else { return }
        let deletedIDs = Set(deleted.map(\.id))
        let deletedSubagentIDs = Set(
            deleted.filter(\.provider.deletesSubagentsWithSession).flatMap { descendantSubagents(of: $0).map(\.id) })
        conversations.removeAll { deletedIDs.contains($0.id) }
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
        if sharingWithOtherWindows {
            for store in windowRegistry.stores where store !== self {
                store.removeDeletedConversations(deleted, sharingWithOtherWindows: false)
            }
        }
    }

    func noteTabStateChanged() {
        tabStateRevision &+= 1
    }

    private func makeTabReadersObserveEachTabsOwnState() {
        _ = tabStateRevision
    }

    private func followTabStateChanges() {
        let openTabIDs = Set(terminalSessionsStorage.map(\.id))
        tabStateSubscriptions = tabStateSubscriptions.filter { openTabIDs.contains($0.key) }
        for tab in terminalSessionsStorage where tabStateSubscriptions[tab.id] == nil {
            tabStateSubscriptions[tab.id] = [
                tab.objectWillChange.sink { [weak self] _ in self?.noteTabStateChanged() },
                tab.$hasExited.dropFirst().filter { $0 }.sink { [weak self, weak tab] _ in
                    guard let tab else { return }
                    self?.noteCLIEnded(in: tab)
                },
            ]
        }
    }

    func replaceTerminal(at index: Int, with session: TerminalSession) {
        defer { persistOpenTabs() }
        let replacedID = terminalSessions[index].id
        let splitChooserWasSelected = selectedTerminalID == replacedID && selectsShownSplitChooser
        terminalSessions[index].close()
        followLightDarkChanges(of: session)
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

    var tabStrip: TerminalTabStrip {
        TerminalTabStrip(
            tabs: terminalSessions.map { TerminalTabStrip.Tab(id: $0.id, projectKey: $0.projectDirectoryKey) },
            splits: terminalSplits
        )
    }

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

    func sides(of split: TerminalSplit) -> TerminalSplit.Sides? {
        tabStrip.sides(of: split)
    }

    func tabGroupKey(of tab: TerminalSession) -> String {
        split(containing: tab.id)?.groupKey ?? tab.projectDirectoryKey
    }

    var tabGroupKeys: [String] {
        terminalSessions.map(tabGroupKey(of:))
    }

    var tabProjectKeysInOrder: [String] {
        var projectKeys: [String] = []
        for tab in terminalSessions where !projectKeys.contains(tab.projectDirectoryKey) {
            projectKeys.append(tab.projectDirectoryKey)
        }
        return projectKeys
    }

    var shownSplit: TerminalSplit? {
        selectedTerminalID.flatMap(split(containing:))
    }

    var terminalSessionsWithSplitsSeparated: [TerminalSession] {
        let tabsByID = Dictionary(uniqueKeysWithValues: terminalSessions.map { ($0.id, $0) })
        return tabStrip.tabsWithSplitsSeparated.compactMap { tabsByID[$0.id] }
    }

    func splitSelectedTerminal(
        with id: UUID,
        on side: TerminalSplit.JoiningSide = .sideItCameFrom,
        orientation: TerminalSplit.Orientation = .sideBySide
    ) {
        guard let selectedTerminalID else { return }
        splitTerminal(selectedTerminalID, with: id, on: side, orientation: orientation)
    }

    func reverseSplit(_ splitID: UUID) {
        var strip = tabStrip
        strip.reverseSplit(splitID)
        guard strip != tabStrip else { return }
        defer { persistOpenTabs() }
        apply(strip)
    }

    func separateSplit(_ splitID: UUID) {
        guard terminalSplits.contains(where: { $0.id == splitID }) else { return }
        defer { persistOpenTabs() }
        var strip = tabStrip
        strip.separateSplit(splitID)
        refreshingHostsOfNewSessionsLeavingTheScreen { apply(strip) }
    }

    func moveIntoShownSplit(_ tabID: UUID, swappingWith side: TerminalSplit.Side) {
        guard let shownSplit, let sides = sides(of: shownSplit),
            let incomingTab = terminalSessions.first(where: { $0.id == tabID }),
            splitChooser(beside: tabID) == nil
        else { return }
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

    private func closeSplitChoosersOfTabsThatClosedOrJoinedASplit() {
        let openTabIDs = Set(terminalSessionsStorage.map(\.id))
        let keptChoosers = terminalSplitChoosers.filter { chooser in
            openTabIDs.contains(chooser.tabID) && !terminalSplits.contains { $0.contains(chooser.tabID) }
        }
        if keptChoosers != terminalSplitChoosers { terminalSplitChoosers = keptChoosers }
    }

    private func forgetWhenClosedTabsWereSelected() {
        let openTabIDs = Set(terminalSessionsStorage.map(\.id))
        if tabIDsByLastSelected.contains(where: { !openTabIDs.contains($0) }) {
            tabIDsByLastSelected.removeAll { !openTabIDs.contains($0) }
        }
    }

    var terminalIDsOnScreen: Set<UUID> {
        if let shownSplit { return shownSplit.tabIDs }
        return selectedTerminalID.map { [$0] } ?? []
    }

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

    func selectTerminal(_ id: UUID?) {
        guard selectedTerminalID != id else {
            selectsShownSplitChooser = false
            return
        }
        defer { persistOpenTabs() }
        refreshingHostsOfNewSessionsLeavingTheScreen { selectedTerminalID = id }
    }

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
        endPlainTerminalTmuxSession(of: closedTab)
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

    var errorMessage: String? { alert?.message }

    func showError(_ message: String) {
        show(StoreAlert(title: StoreAlert.defaultTitle, message: message))
    }

    func show(_ newAlert: StoreAlert) {
        if alert == nil {
            alert = newAlert
        } else {
            waitingAlerts.append(newAlert)
        }
    }

    func dismissAlert(_ dismissedAlert: StoreAlert) {
        guard alert?.id == dismissedAlert.id else { return }
        alert = waitingAlerts.isEmpty ? nil : waitingAlerts.removeFirst()
    }

    func dismissError() {
        if let alert { dismissAlert(alert) }
    }
}
