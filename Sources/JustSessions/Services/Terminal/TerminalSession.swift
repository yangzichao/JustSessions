import AppKit
import Combine
import SwiftTerm

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published private(set) var conversation: Conversation?
    /// The tool whose CLI the tab runs; nil for a plain terminal, which runs a shell and is no session.
    let provider: ConversationProvider?
    let projectPath: String
    /// The machine the tab's CLI runs on.
    let host: SessionHost
    /// Nil for a plain terminal.
    let action: ConversationAction?
    @Published private(set) var displayTitle: String
    let command: NativeCLICommand
    let terminalView: SelectableTerminalView
    /// The session id a new Claude Code tab was started with (`--session-id`), when the CLI accepts one.
    let preassignedSessionID: String?
    /// For a Branch tab, the session it forked. The CLI runs a new session, so this one is never the tab's own.
    let branchedFromSessionID: String?
    let launchedAt = Date()
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
    /// The session a Claude Code CLI moved to, as with `/clear`, that a refresh already looked for; see
    /// `followClaudeSessionSwitch`.
    var sessionIDRefreshedForAfterCLISwitch: String?
    var onProcessFinished: (() -> Void)?

    /// A tab reopened at launch for a session whose CLI no longer runs starts it only once shown, the way a browser
    /// loads a restored tab once you select it. Until then it runs nothing.
    @Published private(set) var isWaitingToBeShown: Bool
    @Published private(set) var hasExited = false
    @Published private(set) var exitCode: Int32?
    /// What the tab's CLI is doing, while it runs and tells; see `ConversationStore+CLIActivitySync`.
    @Published private(set) var cliActivity: CLIActivity?

    private let processObserver: TerminalProcessObserver
    private var hasStarted = false
    private var isClosed = false

    var processID: Int32 { terminalView.process.shellPid }
    /// The CLI's process on this Mac, or 0 while it is unknown: the tab's own process, unless the CLI runs in tmux.
    var cliProcessID: Int32 {
        tmuxSessionName == nil ? processID : tmuxPaneProcessID ?? 0
    }
    var projectDirectoryKey: String {
        ProjectLocation(host: host, path: projectPath).key
    }
    var isPlainTerminal: Bool { provider == nil }
    /// Its process runs, or starts once the tab's view appears: not ended, and not waiting to be shown.
    var isRunning: Bool { !hasExited && !isWaitingToBeShown }
    var runStatus: SessionRunStatus {
        if isWaitingToBeShown { return .waitingToBeShown }
        return hasExited ? .ended : .running(cliActivity)
    }
    /// A New session or Branch tab, whose session id the app learns once the CLI writes it.
    var startsNewSession: Bool { action?.startsNewSession ?? false }

    init(
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
        startsOnceShown: Bool = false
    ) {
        self.conversation = conversation
        self.provider = provider
        self.projectPath = projectPath
        self.host = host
        self.sessionIDsKnownAtLaunch = sessionIDsKnownAtLaunch
        self.tmuxSessionName = tmuxSessionName
        self.action = action
        self.displayTitle = displayTitle
        self.command = command
        self.preassignedSessionID = preassignedSessionID
        self.branchedFromSessionID = branchedFromSessionID
        self.isWaitingToBeShown = startsOnceShown
        self.terminalView = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        self.processObserver = TerminalProcessObserver()
        terminalView.sendsShiftReturnAsCSIu = host == .thisMac && tmuxSessionName != nil
        terminalView.processDelegate = processObserver
        processObserver.session = self
    }

    func startIfNeeded() {
        guard !hasStarted && !isClosed && !isWaitingToBeShown else { return }
        hasStarted = true
        terminalView.startProcess(
            executable: command.executablePath,
            args: command.arguments,
            environment: command.environment,
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
        guard !isClosed else { return }
        self.exitCode = exitCode
        hasExited = true
        cliActivity = nil
        onProcessFinished?()
    }

    /// Returns whether the activity changed. An ended CLI keeps none.
    @discardableResult
    func updateCLIActivity(_ activity: CLIActivity?) -> Bool {
        guard !hasExited, cliActivity != activity else { return false }
        cliActivity = activity
        return true
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
    /// SIGTERM of SwiftTerm's `terminate()`, which also leaves the terminal open, so a plain terminal's shell would
    /// otherwise outlive its tab. A tmux client detaches on SIGHUP and leaves its CLI running.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        guard hasStarted && !hasExited else { return }
        let processID = self.processID
        // kill(0) or kill(-1) would signal the app itself or every process of the user.
        if processID > 0 { kill(processID, SIGHUP) }
        terminalView.terminate()
        ClosedTabProcessReaper.reapOnceExited(processID)
    }
}
