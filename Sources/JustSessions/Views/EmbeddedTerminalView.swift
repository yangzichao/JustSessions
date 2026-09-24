import SwiftTerm
import SwiftUI

struct EmbeddedTerminalView: NSViewRepresentable {
    let session: TerminalSession
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = session.terminalView
        session.startIfNeeded()
        context.coordinator.wasActive = isActive
        if isActive { focus(terminalView, coordinator: context.coordinator) }
        return terminalView
    }

    func updateNSView(_ terminalView: LocalProcessTerminalView, context: Context) {
        if isActive && !context.coordinator.wasActive {
            focus(terminalView, coordinator: context.coordinator)
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
