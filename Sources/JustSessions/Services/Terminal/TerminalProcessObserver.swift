import SwiftTerm

final class TerminalProcessObserver: LocalProcessTerminalViewDelegate, @unchecked Sendable {
    weak var session: TerminalSession?

    func titleChanged(_ title: String) {
        let target = session
        Task { @MainActor [weak target] in
            target?.updateTerminalTitle(title)
        }
    }

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
