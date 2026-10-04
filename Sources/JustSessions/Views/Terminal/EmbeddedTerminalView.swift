import SwiftTerm
import SwiftUI

struct EmbeddedTerminalView: NSViewRepresentable {
    let session: TerminalSession
    /// On screen: the selected tab, or a tab docked to a pane. An invisible terminal coalesces its output.
    let isVisible: Bool
    /// Holding the keyboard: visible and in the focused pane.
    let isFocused: Bool
    /// Called when a click inside the terminal takes the keyboard, so the focused pane follows.
    var onFocus: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = session.terminalView
        terminalView.setWorkspaceActive(isVisible)
        terminalView.onFocusClick = onFocus
        session.startIfNeeded()
        context.coordinator.wasFocused = isFocused
        if isFocused { focus(terminalView, coordinator: context.coordinator) }
        return terminalView
    }

    func updateNSView(_ terminalView: LocalProcessTerminalView, context: Context) {
        session.terminalView.setWorkspaceActive(isVisible)
        session.terminalView.onFocusClick = onFocus
        if isFocused && !context.coordinator.wasFocused {
            focus(terminalView, coordinator: context.coordinator)
        }
        context.coordinator.wasFocused = isFocused
    }

    private func focus(_ terminalView: LocalProcessTerminalView, coordinator: Coordinator) {
        DispatchQueue.main.async { [weak terminalView, weak coordinator] in
            guard let terminalView, coordinator?.wasFocused == true else { return }
            terminalView.window?.makeFirstResponder(terminalView)
        }
    }

    final class Coordinator {
        var wasFocused = false
    }
}
