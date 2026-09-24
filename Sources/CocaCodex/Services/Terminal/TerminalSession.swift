import AppKit
import Combine
import SwiftTerm

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published private(set) var conversation: Conversation?
    let provider: ConversationProvider
    let projectPath: String
    let action: ConversationAction
    @Published private(set) var displayTitle: String
    let command: NativeCLICommand
    let terminalView: SelectableTerminalView

    @Published private(set) var hasExited = false
    @Published private(set) var exitCode: Int32?
    @Published private(set) var allowsCLIMouseInput = false
    @Published private(set) var hasSelection = false

    private let processObserver: TerminalProcessObserver
    private var hasStarted = false
    private var isClosed = false

    var projectName: String { URL(fileURLWithPath: projectPath).lastPathComponent }
    var processID: Int32 { terminalView.process.shellPid }
    var projectDirectoryKey: String {
        URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath().path
    }

    init(
        conversation: Conversation?,
        provider: ConversationProvider,
        projectPath: String,
        action: ConversationAction,
        displayTitle: String,
        command: NativeCLICommand
    ) {
        self.conversation = conversation
        self.provider = provider
        self.projectPath = projectPath
        self.action = action
        self.displayTitle = displayTitle
        self.command = command
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
    }

    func synchronize(conversation: Conversation, displayTitle: String) {
        self.conversation = conversation
        self.displayTitle = displayTitle
    }

    func setCLIMouseInputEnabled(_ enabled: Bool) {
        allowsCLIMouseInput = enabled
        terminalView.allowMouseReporting = enabled
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
