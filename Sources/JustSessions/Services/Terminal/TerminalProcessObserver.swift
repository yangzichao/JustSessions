import SwiftTerm

/// Tells a tab what its terminal hears from the tab's process: the titles it sets and how it ends. A SwiftTerm
/// terminal reaches it as its process delegate, a Ghostty terminal through `titleChanged` and `processEnded`.
final class TerminalProcessObserver: LocalProcessTerminalViewDelegate, @unchecked Sendable {
    weak var session: TerminalSession?

    /// A CLI in tmux reaches the tab's terminal through tmux's `set-titles`; see `ThisMacTmuxServer`.
    func titleChanged(_ title: String) {
        let target = session
        Task { @MainActor [weak target] in
            target?.updateTerminalTitle(title)
        }
    }

    /// `rawWaitStatus` is the status `waitpid` gave; see `ProcessWaitStatus`.
    func processEnded(rawWaitStatus: Int32?) {
        let target = session
        let exitCode = rawWaitStatus.flatMap(ProcessWaitStatus.exitCode(fromWaitStatus:))
        Task { @MainActor [weak target] in
            target?.processFinished(exitCode: exitCode)
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        titleChanged(title)
    }

    /// SwiftTerm's `exitCode` is the raw wait status.
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        processEnded(rawWaitStatus: exitCode)
    }
}
