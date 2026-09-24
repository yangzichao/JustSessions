import SwiftTerm
import SwiftUI

struct EmbeddedTerminalView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = session.terminalView
        session.startIfNeeded()
        DispatchQueue.main.async { [weak terminalView] in
            guard let terminalView else { return }
            terminalView.window?.makeFirstResponder(terminalView)
        }
        return terminalView
    }

    func updateNSView(_ terminalView: LocalProcessTerminalView, context: Context) {}
}
