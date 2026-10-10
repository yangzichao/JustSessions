import SwiftUI

struct EmbeddedTerminalView: NSViewRepresentable {
    let session: TerminalSession
    /// The terminal is on screen, full width or as either half of a split, so it draws its output.
    let isShown: Bool
    /// The tab is selected, so its terminal gets the keyboard.
    let isActive: Bool
    /// Called when a click lands on the terminal or its margin, or files are dropped on it, before the terminal takes
    /// the keyboard.
    let onFocus: () -> Void
    /// Builds the menu a right-click on the terminal or its margin shows.
    let makeContextMenu: () -> NSMenu

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> TerminalInsetView {
        let terminalView = session.terminalView
        terminalView.setWorkspaceActive(isShown)
        terminalView.onFocus = onFocus
        terminalView.makeContextMenu = makeContextMenu
        session.startIfNeeded()
        context.coordinator.wasActive = isActive
        if isActive { focus(terminalView, coordinator: context.coordinator) }
        return TerminalInsetView(terminalView: terminalView)
    }

    func updateNSView(_ insetView: TerminalInsetView, context: Context) {
        insetView.terminalView.setWorkspaceActive(isShown)
        insetView.terminalView.onFocus = onFocus
        insetView.terminalView.makeContextMenu = makeContextMenu
        if isActive && !context.coordinator.wasActive {
            focus(insetView.terminalView, coordinator: context.coordinator)
        }
        context.coordinator.wasActive = isActive
    }

    /// The tab's session holds its terminal, and these closures hold the session, so a closed tab's terminal would
    /// otherwise never be freed: for Ghostty, a GPU surface and its scrollback.
    static func dismantleNSView(_ insetView: TerminalInsetView, coordinator: Coordinator) {
        insetView.terminalView.onFocus = nil
        insetView.terminalView.makeContextMenu = nil
    }

    private func focus(_ terminalView: any TabTerminalView, coordinator: Coordinator) {
        DispatchQueue.main.async { [weak terminalView, weak coordinator] in
            guard let terminalView, coordinator?.wasActive == true else { return }
            terminalView.window?.makeFirstResponder(terminalView)
        }
    }

    final class Coordinator {
        var wasActive = false
    }
}
