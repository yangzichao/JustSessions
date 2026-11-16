import AppKit
import Combine

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published private(set) var conversation: Conversation?
    /// The tool whose CLI the tab runs; nil for a plain terminal, which runs a shell and is no session.
    let provider: ConversationProvider?
    let projectPath: String
    /// The machine the tab's CLI runs on.
    let host: SessionHost
    /// The project's key, found once as a session's is: on this Mac it resolves symlinks on disk, and every project row
    /// reads every tab's key each time the sidebar draws.
    let projectDirectoryKey: String
    /// Nil for a plain terminal.
    let action: ConversationAction?
    @Published private(set) var displayTitle: String
    let command: NativeCLICommand
    /// What draws the tab's terminal, chosen when the tab opens; see `TerminalEngineStore`.
    let engine: TerminalEngine
    let terminalView: any TabTerminalView
    /// The tab's find bar, which searches its terminal; see `TerminalFindShortcuts` for when ⌘F opens it.
    let findState: TerminalFindState
    /// The conversation map's outline of the linked session and its reader for ⌘D (TAB-10, TRM-74), kept with the tab so
    /// it follows the tab to another window.
    let conversationOutline: ConversationOutlineModel
    /// What ⌘D, ⌘', and ⇧⌘' say over the terminal; see `TerminalTabBookmarks`.
    let bookmarkNotices: TerminalBookmarkNoticeState
    /// The session id a new Claude Code tab was started with (`--session-id`), when the CLI accepts one.
    let preassignedSessionID: String?
    /// For a Branch tab, the session it forked. The CLI runs a new session, so this one is never the tab's own.
    let branchedFromSessionID: String?
    /// A new session's tab started with **Delete the session when its tab closes**. Once the tab is linked, its
    /// session carries the choice instead, in `SessionsDeletedWhenTabCloses`, so it outlives the tab.
    var deletesSessionWhenClosed = false
    let launchedAt = Date()
    /// When its process started, which for a tab that waited to be shown is after it was made.
    private(set) var startedAt: Date?
    /// For a new session or branch linked by appearance: the tool's session ids listed on the host when the tab
    /// started. The first session that appears after that in the same project is this tab's.
    let sessionIDsKnownAtLaunch: Set<String>
    /// The tmux session the tab's CLI runs in, on this Mac or an SSH host. A new session's or branch's tab renames
    /// it once its session is known, and so does a tab that follows its CLI to another session.
    var tmuxSessionName: String?
    /// For a tab whose CLI runs in tmux on this Mac: the CLI's process, which the tmux server started rather than
    /// the tab. Found once the tmux session runs.
    var tmuxPaneProcessID: Int32?
    /// Refreshes spent picking up a new session's first prompt as its title; see new session discovery.
    var titleRefreshCount = 0
    /// The session the tab's CLI is in, which no refresh had listed when the tab found it, once a refresh looked for
    /// it; see `followCodexThreads` and `followLiveSessions`.
    var cliSessionIDRefreshedFor: String?
    /// For a Claude Code tab, the session its CLI moved to that no refresh has listed yet; see
    /// `followClaudeSessionSwitch`.
    var unlistedClaudeSession: UnlistedClaudeSession?
    /// The title the tab's CLI last gave its terminal. A Codex CLI's title names its thread; see `CodexThreadTitle`.
    private(set) var terminalTitle: String?
    var onProcessFinished: (() -> Void)?
    /// Says what a link in the tab's terminal points to and opens it; see `TerminalLinkActions` for what a ⌘-click and
    /// a right-click on one do.
    var linkOpener: TerminalLinkOpener
    /// For a tab on an SSH host: copies files dropped on it to the host before typing their paths there.
    let sshFileDrop: TerminalSSHFileDrop?

    /// A tab reopened at launch for a session whose CLI no longer runs starts it only once shown, the way a browser
    /// loads a restored tab once you select it. Until then it runs nothing.
    @Published private(set) var isWaitingToBeShown: Bool
    /// The tab's CLI has ended. Its tmux client can still run, showing a failed CLI's output; see `ThisMacTmuxDeadPane`.
    @Published private(set) var hasExited = false
    /// How the CLI ended: a failed CLI's own status in tmux on this Mac, and otherwise the tab's process's.
    @Published private(set) var exitCode: Int32?
    /// When the CLI ended, once it has.
    private(set) var exitedAt: Date?
    /// What the tab's CLI is doing, while it runs and tells; see `ConversationStore+CLIActivitySync`.
    @Published private(set) var cliActivity: CLIActivity?
    /// The tab's CLI finished a turn while the tab was off screen, and you have not looked since. The store keeps
    /// the marks and sets this one; see `ConversationStore+UnseenFinishedTurns`.
    @Published private(set) var hasUnseenFinishedTurn = false
    /// The tab's connection dropped and the app reconnects it on its own once the host lists its tmux session; see
    /// `RemoteTabReconnector`.
    @Published var isWaitingToReconnect = false
    /// The tab's connection ended because you ended the login it went through, with Disconnect, so it isn't
    /// reconnected on its own.
    var connectionEndedOnPurpose = false

    private let processObserver: TerminalProcessObserver
    private var hasStarted = false
    /// The tab's own process has ended, which for a CLI in tmux is the tmux client.
    private var hasProcessExited = false
    private var isClosed = false

    var processID: Int32 { terminalView.processID }
    /// The CLI's process on this Mac, or 0 while it is unknown: the tab's own process, unless the CLI runs in tmux.
    var cliProcessID: Int32 {
        tmuxSessionName == nil ? processID : tmuxPaneProcessID ?? 0
    }
    var isPlainTerminal: Bool { provider == nil }
    /// A CLI that ended with an error this soon after it started most likely couldn't start, as when tmux on its SSH
    /// host can't reach its server and the tab ends at once.
    static let endedSoonAfterStartingInterval: TimeInterval = 30
    /// The CLI ended with an error within `endedSoonAfterStartingInterval` of starting.
    var endedWithErrorSoonAfterStarting: Bool {
        guard let exitCode, exitCode != 0, let startedAt, let exitedAt else { return false }
        return exitedAt.timeIntervalSince(startedAt) < Self.endedSoonAfterStartingInterval
    }
    /// The tmux session on this Mac still showing the tab's failed CLI, whose pane tmux keeps while the tab's client is
    /// attached. Nil once the client has gone, and for any other tab.
    var tmuxSessionKeptForEndedCLI: String? {
        host == .thisMac && hasExited && hasStarted && !hasProcessExited ? tmuxSessionName : nil
    }
    /// Its process runs, or starts once the tab's view appears: not ended, and not waiting to be shown.
    var isRunning: Bool { !hasExited && !isWaitingToBeShown }
    var runStatus: SessionRunStatus {
        if isWaitingToBeShown { return .waitingToBeShown }
        return hasExited ? .ended : SessionRunStatus.running(cliActivity).markingUnseenFinishedTurn(hasUnseenFinishedTurn)
    }
    /// Its CLI runs and waits on you: stopped for your answer, or done with a turn you have not seen.
    var isWaitingForYou: Bool {
        isRunning && WaitingForYou.includes(activity: cliActivity, hasUnseenFinishedTurn: hasUnseenFinishedTurn)
    }
    /// A New session or Branch tab, whose session id the app learns once the CLI writes it.
    var startsNewSession: Bool { action?.startsNewSession ?? false }
    /// A tab on an SSH host whose `ssh` ended with its connection error, as when the Mac slept, so its CLI or shell may
    /// still run in tmux there. A CLI or shell that ended, or a client that detached, ends `ssh` with another status.
    /// One that ended so right after starting most likely couldn't connect, as when the host refused the login, and
    /// Check host is the way on.
    var hasDroppedConnectionToTmux: Bool {
        host != .thisMac && tmuxSessionName != nil && hasExited
            && exitCode == RemoteHostCommandRunner.connectionFailureExitStatus && !connectionEndedOnPurpose
            && !endedWithErrorSoonAfterStarting
    }

    init(
        engine: TerminalEngine,
        conversation: Conversation?,
        provider: ConversationProvider?,
        projectPath: String,
        action: ConversationAction?,
        displayTitle: String,
        command: NativeCLICommand,
        preassignedSessionID: String? = nil,
        branchedFromSessionID: String? = nil,
        host: SessionHost = .thisMac,
        sessionIDsKnownAtLaunch: Set<String> = [],
        tmuxSessionName: String? = nil,
        startsOnceShown: Bool = false,
        tmuxHistory: TmuxHistory? = nil
    ) {
        self.engine = engine
        self.conversation = conversation
        self.provider = provider
        self.projectPath = projectPath
        self.host = host
        projectDirectoryKey = ProjectLocation(host: host, path: projectPath).key
        self.sessionIDsKnownAtLaunch = sessionIDsKnownAtLaunch
        self.tmuxSessionName = tmuxSessionName
        self.action = action
        self.displayTitle = displayTitle
        self.command = command
        self.preassignedSessionID = preassignedSessionID
        self.branchedFromSessionID = branchedFromSessionID
        self.isWaitingToBeShown = startsOnceShown
        let terminalView = engine.makeTabTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        self.terminalView = terminalView
        // A plain terminal's shell history is in tmux's, while it runs there; see `PlainTerminalFinder`.
        self.findState = TerminalFindState(finder: tmuxHistory.map { tmuxHistory in
            PlainTerminalFinder(terminalFinder: terminalView, tmuxHistory: tmuxHistory) { terminalView.isOnAlternateScreen }
        } ?? terminalView)
        self.conversationOutline = ConversationOutlineModel()
        self.bookmarkNotices = TerminalBookmarkNoticeState()
        self.processObserver = TerminalProcessObserver()
        self.linkOpener = TerminalLinkOpener(host: host, workingDirectory: projectPath)
        self.sshFileDrop = host.sshDestination.map { TerminalSSHFileDrop(host: $0) }
        // A plain terminal's shell gets the keys as it would outside tmux: tmux passes a program that doesn't ask for
        // extended keys their plain bytes, and the tab sends those.
        terminalView.cliRunsInTmux = tmuxSessionName != nil && provider != nil
        terminalView.promptSelection.layout = provider.flatMap(CLIPromptLayout.init(provider:))
        terminalView.acceptsDroppedFiles = true
        if let sshFileDrop {
            terminalView.copyDroppedFilesToHost = { [weak self] fileURLs in self?.copyDroppedFilesToHost(fileURLs) ?? false }
            terminalView.imagePaste.copyToHost = { [weak self] image in self?.copyPastedImageToHost(image) }
            sshFileDrop.typePaths = { [weak self] hostPaths in self?.typeCopiedPaths(hostPaths) }
        }
        terminalView.connectProcessObserver(processObserver)
        processObserver.session = self
    }

    func startIfNeeded() {
        guard !hasStarted && !isClosed && !isWaitingToBeShown else { return }
        hasStarted = true
        startedAt = Date()
        terminalView.startProcess(
            executable: command.executablePath,
            args: command.arguments,
            environment: command.environment,
            execName: nil,
            currentDirectory: command.workingDirectory
        )
    }

    /// Starts a tab that waited to be shown, now that it is.
    func startNowThatItIsShown() {
        guard isWaitingToBeShown else { return }
        isWaitingToBeShown = false
        startIfNeeded()
    }

    func processFinished(exitCode: Int32?) {
        hasProcessExited = true
        // A failed CLI in tmux ended before its client did, and its tab keeps the CLI's own status.
        guard !isClosed, !hasExited else { return }
        cliEnded(exitCode: exitCode)
    }

    /// tmux names a failed CLI's status in the title; see `ThisMacTmuxDeadPane`.
    func updateTerminalTitle(_ title: String) {
        if host == .thisMac, tmuxSessionName != nil, let deadPane = ThisMacTmuxDeadPane(terminalTitle: title) {
            guard !isClosed, !hasExited else { return }
            cliEnded(exitCode: deadPane.exitCode)
            return
        }
        terminalTitle = title
    }

    /// A tab whose CLI has ended, or that waits to be shown, takes no files.
    private func copyDroppedFilesToHost(_ fileURLs: [URL]) -> Bool {
        guard isRunning, !isClosed, let sshFileDrop else { return false }
        return sshFileDrop.take(fileURLs)
    }

    /// Nor a pasted image, which it would copy to the host.
    private func copyPastedImageToHost(_ image: TerminalClipboardImage) {
        guard isRunning, !isClosed, let sshFileDrop else { return }
        sshFileDrop.take(image)
    }

    private func typeCopiedPaths(_ hostPaths: [String]) {
        guard isRunning, !isClosed else { return }
        terminalView.typeDroppedPaths(hostPaths)
    }

    private func cliEnded(exitCode: Int32?) {
        sshFileDrop?.cancel()
        self.exitCode = exitCode
        exitedAt = Date()
        hasExited = true
        cliActivity = nil
        hasUnseenFinishedTurn = false
        onProcessFinished?()
        if hasDroppedConnectionToTmux {
            NotificationCenter.default.post(name: RemoteTabReconnector.connectionDroppedNotification, object: self)
        }
    }

    /// Returns whether the activity changed. An ended CLI keeps none.
    @discardableResult
    func updateCLIActivity(_ activity: CLIActivity?) -> Bool {
        guard !hasExited, cliActivity != activity else { return false }
        cliActivity = activity
        return true
    }

    func updateHasUnseenFinishedTurn(_ isUnseen: Bool) {
        guard !hasExited, hasUnseenFinishedTurn != isUnseen else { return }
        hasUnseenFinishedTurn = isUnseen
    }

    func synchronize(conversation: Conversation, displayTitle: String) {
        if self.conversation != conversation { self.conversation = conversation }
        updateDisplayTitle(displayTitle)
    }

    func updateDisplayTitle(_ title: String) {
        guard displayTitle != title else { return }
        displayTitle = title
    }

    /// Hangs up on the tab's process with SIGHUP, as closing a terminal window does. An interactive shell ignores the
    /// SIGTERM of the terminal's `terminate()`, which also leaves the terminal open, so a plain terminal's shell would
    /// otherwise outlive its tab. A tmux client detaches on SIGHUP and leaves its CLI running, or ends the session of a
    /// failed CLI it still shows. A copy of files dropped on the tab to its SSH host stops, and its conversation map's outline and bookmark notice go.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        sshFileDrop?.cancel()
        conversationOutline.release()
        bookmarkNotices.dismiss()
        guard hasStarted && !hasProcessExited else { return }
        let processID = self.processID
        // kill(0) or kill(-1) would signal the app itself or every process of the user.
        if processID > 0 { kill(processID, SIGHUP) }
        terminalView.terminate()
        ClosedTabProcessReaper.reapOnceExited(processID)
    }
}
