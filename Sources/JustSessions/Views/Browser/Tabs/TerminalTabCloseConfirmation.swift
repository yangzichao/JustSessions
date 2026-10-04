import SwiftUI

/// Mouse and keyboard closes share the same choice about keeping a tmux CLI running.
struct TerminalTabCloseConfirmation: ViewModifier {
    @ObservedObject var store: ConversationStore
    @Binding var closingSessionID: UUID?

    private var closingTabTmuxHost: SessionHost? {
        store.terminalSessions.first { $0.id == closingSessionID && $0.canKeepCLIRunningAfterClose }?.host
    }

    private var isClosingPlainTerminal: Bool {
        store.terminalSessions.first { $0.id == closingSessionID }?.isPlainTerminal == true
    }

    private var closingDialogTitle: String {
        if closingTabTmuxHost != nil { return "Close this tab?" }
        return isClosingPlainTerminal ? "Close this terminal?" : "End this CLI session?"
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            closingDialogTitle,
            isPresented: Binding(isPresenting: $closingSessionID)
        ) {
            if closingTabTmuxHost != nil {
                Button("Keep running") {
                    if let closingSessionID { store.closeTerminal(closingSessionID, endingTmuxSession: false) }
                    closingSessionID = nil
                }
            }
            Button(isClosingPlainTerminal ? "Close terminal" : "End session", role: .destructive) {
                if let closingSessionID { store.closeTerminal(closingSessionID, endingTmuxSession: true) }
                closingSessionID = nil
            }
        } message: {
            if let closingTabTmuxHost {
                Text("Keep running leaves the CLI running in tmux on \(closingTabTmuxHost.nameInSentence); click the session to reattach. End session stops it.")
            } else if isClosingPlainTerminal {
                Text("The shell and anything still running in it will stop.")
            } else {
                Text("The terminal process will stop. Sessions saved by the CLI will appear in the project list after refresh.")
            }
        }
        .dismissesOnClickOutside(item: $closingSessionID)
    }
}
