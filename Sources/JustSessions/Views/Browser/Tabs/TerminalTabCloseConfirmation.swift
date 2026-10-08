import SwiftUI

/// Mouse and keyboard closes share the same choice about keeping a tmux CLI running. Don't ask again saves the
/// answer picked with it, so later closes do the same without asking; Settings can change it back.
///
/// Return closes the tab, and Escape cancels. The dialogs are alerts rather than confirmation dialogs: on macOS, a
/// confirmation dialog gives no button Return.
struct TerminalTabCloseConfirmation: ViewModifier {
    @ObservedObject var store: ConversationStore
    @Binding var closingSessionID: UUID?
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    /// Don't ask again, ticked in the dialog that shows now; unticked again each time a dialog closes.
    @State private var savesTabCloseChoice = false

    private var closingTabTmuxHost: SessionHost? {
        store.terminalSessions.first { $0.id == closingSessionID && $0.canKeepCLIRunningAfterClose }?.host
    }

    private var isClosingPlainTerminal: Bool {
        store.terminalSessions.first { $0.id == closingSessionID }?.isPlainTerminal == true
    }

    func body(content: Content) -> some View {
        content
            .alert(
                "Close this tab?",
                isPresented: closingDialogPresentation(whileTmuxCanKeepCLIRunning: true)
            ) {
                // Return keeps the CLI running: that close can be undone by reattaching.
                Button("Keep running") { closeTab(endingTmuxSession: false) }
                    .keyboardShortcut(.defaultAction)
                Button("End session", role: .destructive) { closeTab(endingTmuxSession: true) }
                Button("Cancel", role: .cancel) { closingSessionID = nil }
            } message: {
                if let closingTabTmuxHost {
                    Text("Keep running leaves the CLI running in tmux on \(closingTabTmuxHost.nameInSentence); click the session to reattach. End session stops it.")
                }
            }
            // Only the dialog above shows the checkbox: a modifier applies to the dialogs it wraps.
            .dialogSuppressionToggle("Don't ask again", isSuppressed: $savesTabCloseChoice)
            .alert(
                isClosingPlainTerminal ? "Close this terminal?" : "End this CLI session?",
                isPresented: closingDialogPresentation(whileTmuxCanKeepCLIRunning: false)
            ) {
                Button(isClosingPlainTerminal ? "Close terminal" : "End session", role: .destructive) {
                    closeTab(endingTmuxSession: true)
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { closingSessionID = nil }
            } message: {
                if isClosingPlainTerminal {
                    Text("The shell and anything still running in it will stop.")
                } else {
                    Text("The terminal process will stop. Sessions saved by the CLI will appear in the project list after refresh.")
                }
            }
            .dismissesOnClickOutside(item: $closingSessionID)
            .onChange(of: closingSessionID) { _, newClosingSessionID in
                if newClosingSessionID == nil { savesTabCloseChoice = false }
            }
    }

    /// Shows one of the two dialogs while a tab waits to close: the one with Keep running when tmux can keep its CLI
    /// running, or else the one that only ends it.
    private func closingDialogPresentation(whileTmuxCanKeepCLIRunning canKeepCLIRunning: Bool) -> Binding<Bool> {
        Binding(
            get: { closingSessionID != nil && (closingTabTmuxHost != nil) == canKeepCLIRunning },
            set: { isPresented in if !isPresented { closingSessionID = nil } }
        )
    }

    /// SwiftUI sets the checkbox's binding before it runs the button's action, so the choice is saved here.
    private func closeTab(endingTmuxSession: Bool) {
        if let closingSessionID {
            if savesTabCloseChoice, closingTabTmuxHost != nil {
                tabCloseChoiceSettingsStore.setChoice(endingTmuxSession ? .endSession : .keepRunning)
            }
            store.closeTerminal(closingSessionID, endingTmuxSession: endingTmuxSession)
        }
        closingSessionID = nil
    }
}
