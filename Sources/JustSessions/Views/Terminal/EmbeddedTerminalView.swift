import SwiftUI

struct EmbeddedTerminalView: NSViewRepresentable {
    let session: TerminalSession
    let isShown: Bool
    let isActive: Bool
    let onFocus: () -> Void
    let makeContextMenu: (_ linkUnderPointer: String?) -> NSMenu
    let onOpenLink: (_ link: String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> TerminalInsetView {
        let terminalView = session.terminalView
        giveCallbacksThatHoldTheSession(to: terminalView)
        session.startIfNeeded()
        context.coordinator.wasActive = isActive
        let insetView = TerminalInsetView(terminalView: terminalView)
        insetView.isShown = isShown
        if isActive { focus(insetView, coordinator: context.coordinator) }
        return insetView
    }

    func updateNSView(_ insetView: TerminalInsetView, context: Context) {
        insetView.isShown = isShown
        giveCallbacksThatHoldTheSession(to: insetView.terminalView)
        if isActive && !context.coordinator.wasActive {
            focus(insetView, coordinator: context.coordinator)
        }
        if !isActive { insetView.takesKeyboardInWindow = false }
        context.coordinator.wasActive = isActive
    }

    static func dismantleNSView(_ insetView: TerminalInsetView, coordinator: Coordinator) {
        if anotherViewHasTakenTheTerminal(of: insetView) { return }
        takeBackCallbacksSoAClosedTabsTerminalCanBeFreed(from: insetView.terminalView)
    }

    private func giveCallbacksThatHoldTheSession(to terminalView: any TabTerminalView) {
        terminalView.onFocus = onFocus
        terminalView.makeContextMenu = makeContextMenu
        terminalView.onOpenLink = onOpenLink
    }

    private static func anotherViewHasTakenTheTerminal(of insetView: TerminalInsetView) -> Bool {
        guard let viewHostingTheTerminal = insetView.terminalView.superview else { return false }
        return viewHostingTheTerminal !== insetView
    }

    private static func takeBackCallbacksSoAClosedTabsTerminalCanBeFreed(from terminalView: any TabTerminalView) {
        terminalView.onFocus = nil
        terminalView.makeContextMenu = nil
        terminalView.onOpenLink = nil
    }

    private func focus(_ insetView: TerminalInsetView, coordinator: Coordinator) {
        DispatchQueue.main.async { [weak insetView, weak coordinator] in
            guard let insetView, coordinator?.wasActive == true else { return }
            insetView.takeKeyboard()
        }
    }

    final class Coordinator {
        var wasActive = false
    }
}
