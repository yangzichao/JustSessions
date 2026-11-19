import AppKit
import Combine

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published private(set) var conversation: Conversation?
    let provider: ConversationProvider?
    let projectPath: String
    let host: SessionHost
    let projectDirectoryKey: String
    let action: ConversationAction?
    @Published private(set) var displayTitle: String
    let command: NativeCLICommand
    let engine: TerminalEngine
    let terminalView: any TabTerminalView
    let findState: TerminalFindState
    let conversationOutline: ConversationOutlineModel
    let bookmarkNotices: TerminalBookmarkNoticeState
    let preassignedSessionID: String?
    let branchedFromSessionID: String?
    var deletesSessionWhenClosed = false
    let launchedAt = Date()
    private(set) var startedAt: Date?
    let sessionIDsKnownAtLaunch: Set<String>
    var tmuxSessionName: String?
    var tmuxPaneProcessID: Int32?
    var titleRefreshCount = 0
    var cliSessionIDRefreshedFor: String?
    var unlistedClaudeSession: UnlistedClaudeSession?
    private(set) var terminalTitle: String?
    var onProcessFinished: (() -> Void)?
    var linkOpener: TerminalLinkOpener
    let sshFileDrop: TerminalSSHFileDrop?

    @Published private(set) var isWaitingToBeShown: Bool
    @Published private(set) var hasExited = false
    @Published private(set) var exitCode: Int32?
    private(set) var exitedAt: Date?
    @Published private(set) var cliActivity: CLIActivity?
    @Published private(set) var hasUnseenFinishedTurn = false
    @Published var isWaitingToReconnect = false
    var connectionEndedOnPurpose = false

    private let processObserver: TerminalProcessObserver
    private var hasStarted = false
    private var hasProcessExited = false
    private var isClosed = false

    var processID: Int32 { terminalView.processID }
    var cliProcessID: Int32 {
        tmuxSessionName == nil ? processID : tmuxPaneProcessID ?? 0
    }
    var isPlainTerminal: Bool { provider == nil }
    static let endedSoonAfterStartingInterval: TimeInterval = 30
    var endedWithErrorSoonAfterStarting: Bool {
        guard let exitCode, exitCode != 0, let startedAt, let exitedAt else { return false }
        return exitedAt.timeIntervalSince(startedAt) < Self.endedSoonAfterStartingInterval
    }
    var tmuxSessionKeptForEndedCLI: String? {
        host == .thisMac && hasExited && hasStarted && !hasProcessExited ? tmuxSessionName : nil
    }
    var isRunning: Bool { !hasExited && !isWaitingToBeShown }
    var runStatus: SessionRunStatus {
        if isWaitingToBeShown { return .waitingToBeShown }
        return hasExited ? .ended : SessionRunStatus.running(cliActivity).markingUnseenFinishedTurn(hasUnseenFinishedTurn)
    }
    var isWaitingForYou: Bool {
        isRunning && WaitingForYou.includes(activity: cliActivity, hasUnseenFinishedTurn: hasUnseenFinishedTurn)
    }
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
        self.findState = TerminalFindState(
            finder: tmuxHistory.map { tmuxHistory in
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

    func startNowThatItIsShown() {
        guard isWaitingToBeShown else { return }
        isWaitingToBeShown = false
        startIfNeeded()
    }

    func processFinished(exitCode: Int32?) {
        hasProcessExited = true
        guard !isClosed, !hasExited else { return }
        cliEnded(exitCode: exitCode)
    }

    func updateTerminalTitle(_ title: String) {
        if host == .thisMac, tmuxSessionName != nil, let deadPane = ThisMacTmuxDeadPane(terminalTitle: title) {
            guard !isClosed, !hasExited else { return }
            cliEnded(exitCode: deadPane.exitCode)
            return
        }
        terminalTitle = title
    }

    private func copyDroppedFilesToHost(_ fileURLs: [URL]) -> Bool {
        guard isRunning, !isClosed, let sshFileDrop else { return false }
        return sshFileDrop.take(fileURLs)
    }

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
