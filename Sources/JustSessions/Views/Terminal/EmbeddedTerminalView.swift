import SwiftTerm
import SwiftUI

struct EmbeddedTerminalView: NSViewRepresentable {
    let session: TerminalSession
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> TerminalInsetView {
        let terminalView = session.terminalView
        terminalView.setWorkspaceActive(isActive)
        session.startIfNeeded()
        context.coordinator.wasActive = isActive
        if isActive { focus(terminalView, coordinator: context.coordinator) }
        return TerminalInsetView(terminalView: terminalView)
    }

    func updateNSView(_ insetView: TerminalInsetView, context: Context) {
        insetView.terminalView.setWorkspaceActive(isActive)
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
