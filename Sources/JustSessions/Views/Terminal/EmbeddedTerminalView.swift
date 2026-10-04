import SwiftTerm
import SwiftUI

struct EmbeddedTerminalView: NSViewRepresentable {
    let session: TerminalSession
    /// The terminal is on screen, full width or as either half of a split, so it draws its output.
    let isShown: Bool
    /// The tab is selected, so its terminal gets the keyboard.
    let isActive: Bool
    /// Called when a click lands on the terminal or its margin, before the terminal takes the keyboard.
    let onFocus: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> TerminalInsetView {
        let terminalView = session.terminalView
        terminalView.setWorkspaceActive(isShown)
        terminalView.onMouseDown = onFocus
        session.startIfNeeded()
        context.coordinator.wasActive = isActive
        if isActive { focus(terminalView, coordinator: context.coordinator) }
        return TerminalInsetView(terminalView: terminalView)
    }

    func updateNSView(_ insetView: TerminalInsetView, context: Context) {
        insetView.terminalView.setWorkspaceActive(isShown)
        insetView.terminalView.onMouseDown = onFocus
        if isActive && !context.coordinator.wasActive {
            focus(insetView.terminalView, coordinator: context.coordinator)
        }
        context.coordinator.wasActive = isActive
    }

    private func focus(_ terminalView: LocalProcessTerminalView, coordinator: Coordinator) {
        DispatchQueue.main.async { [weak terminalView, weak coordinator] in
            guard let terminalView, coordinator?.wasActive == true else { return }
            terminalView.window?.makeFirstResponder(terminalView)
        }
    }

    final class Coordinator {
        var wasActive = false
    }
}
