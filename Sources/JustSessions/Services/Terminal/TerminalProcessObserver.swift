import SwiftTerm

final class TerminalProcessObserver: LocalProcessTerminalViewDelegate, @unchecked Sendable {
    weak var session: TerminalSession?

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    /// A CLI in tmux reaches the tab's terminal through tmux's `set-titles`; see `ThisMacTmuxServer`.
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        let target = session
        Task { @MainActor [weak target] in
            target?.updateTerminalTitle(title)
        }
    }

    /// `exitCode` is the raw wait status; see `ProcessWaitStatus`.
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        let target = session
        let exitCode = exitCode.flatMap(ProcessWaitStatus.exitCode(fromWaitStatus:))
        Task { @MainActor [weak target] in
            target?.processFinished(exitCode: exitCode)
        }
    }
}
