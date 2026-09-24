import SwiftTerm

final class TerminalProcessObserver: LocalProcessTerminalViewDelegate, @unchecked Sendable {
    weak var session: TerminalSession?

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        let target = session
        Task { @MainActor [weak target] in
            target?.processFinished(exitCode: exitCode)
        }
    }
}
