import AppKit
import Combine
import SwiftTerm

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published private(set) var conversation: Conversation?
    let provider: ConversationProvider
    let projectPath: String
    /// The SSH host the tab's CLI runs on, or nil for this Mac.
    let remoteHost: String?
    let action: ConversationAction
    @Published private(set) var displayTitle: String
    let command: NativeCLICommand
    let terminalView: SelectableTerminalView
    /// The session id a new Claude Code tab was started with (`--session-id`), when the CLI accepts one.
    let preassignedSessionID: String?
    /// For a Branch tab, the session it forked. The CLI runs a new session, so this one is never the tab's own.
    let branchedFromSessionID: String?
    let launchedAt = Date()
    /// For a new session or branch on a remote host: the host's session ids listed when the tab started. The
    /// first session that appears after that in the same project is this tab's.
    let sessionIDsKnownAtLaunch: Set<String>
    /// The tmux session a remote tab's CLI runs in. A new session's or branch's tab renames it once its session is known.
    var remoteTmuxSessionName: String?
    /// Refreshes spent picking up a new session's first prompt as its title; see new session discovery.
    var titleRefreshCount = 0
    var onProcessFinished: (() -> Void)?

    @Published private(set) var hasExited = false
    @Published private(set) var exitCode: Int32?
    @Published private(set) var hasSelection = false

    private let processObserver: TerminalProcessObserver
    private var hasStarted = false
    private var isClosed = false

    var processID: Int32 { terminalView.process.shellPid }
    var projectDirectoryKey: String {
        if let remoteHost { return RemoteProjectKey.key(host: remoteHost, projectPath: projectPath) }
        return URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath().path
    }

    init(
        conversation: Conversation?,
        provider: ConversationProvider,
        projectPath: String,
        action: ConversationAction,
        displayTitle: String,
        command: NativeCLICommand,
        preassignedSessionID: String? = nil,
        branchedFromSessionID: String? = nil,
        remoteHost: String? = nil,
        sessionIDsKnownAtLaunch: Set<String> = [],
        remoteTmuxSessionName: String? = nil
    ) {
        self.conversation = conversation
        self.provider = provider
        self.projectPath = projectPath
        self.remoteHost = remoteHost
        self.sessionIDsKnownAtLaunch = sessionIDsKnownAtLaunch
        self.remoteTmuxSessionName = remoteTmuxSessionName
        self.action = action
        self.displayTitle = displayTitle
        self.command = command
        self.preassignedSessionID = preassignedSessionID
        self.branchedFromSessionID = branchedFromSessionID
        self.terminalView = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        self.processObserver = TerminalProcessObserver()
        terminalView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.processDelegate = processObserver
        terminalView.onSelectionChanged = { [weak self] hasSelection in
            self?.hasSelection = hasSelection
        }
        processObserver.session = self
    }

    func startIfNeeded() {
        guard !hasStarted && !isClosed else { return }
        hasStarted = true
        terminalView.startProcess(
            executable: command.executablePath,
            args: command.arguments,
            environment: command.environment,
            currentDirectory: command.workingDirectory
        )
    }

    func processFinished(exitCode: Int32?) {
        guard !isClosed else { return }
        self.exitCode = exitCode
        hasExited = true
        onProcessFinished?()
    }

    func synchronize(conversation: Conversation, displayTitle: String) {
        self.conversation = conversation
        self.displayTitle = displayTitle
    }

    func updateDisplayTitle(_ title: String) {
        guard displayTitle != title else { return }
        displayTitle = title
    }

    func copySelection() {
        guard terminalView.selectionActive else { return }
        terminalView.copy(self)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        if hasStarted && !hasExited { terminalView.terminate() }
    }
}
