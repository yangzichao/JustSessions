import SwiftUI

/// Mouse and keyboard closes share the same choice about keeping a tmux CLI running, and about closing a plain
/// terminal. Don't ask again saves the answer picked with it, so later closes do the same without asking; Settings can
/// change it back.
///
/// Return closes the tab, and Escape cancels. The dialogs are alerts rather than confirmation dialogs: on macOS, a
/// confirmation dialog gives no button Return.
struct TerminalTabCloseConfirmation: ViewModifier {
    @ObservedObject var store: ConversationStore
    @Binding var closingSessionID: UUID?
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    let plainTerminalCloseChoiceSettingsStore: PlainTerminalCloseChoiceSettingsStore
    /// Don't ask again, ticked in the dialog that shows now; unticked again each time a dialog closes.
    @State private var savesCloseChoice = false

    private enum ClosingDialog {
        /// Keep running or End session, for a CLI tmux can keep running.
        case keepOrEndCLI
        case closePlainTerminal
        /// End session only, for a CLI that ends with its tab.
        case endCLI
    }

    private var closingDialog: ClosingDialog? {
        guard closingSessionID != nil else { return nil }
        let closingTab = store.terminalSessions.first { $0.id == closingSessionID }
        if closingTab?.canKeepCLIRunningAfterClose == true { return .keepOrEndCLI }
        return closingTab?.isPlainTerminal == true ? .closePlainTerminal : .endCLI
    }

    private var closingTabTmuxHost: SessionHost? {
        store.terminalSessions.first { $0.id == closingSessionID && $0.canKeepCLIRunningAfterClose }?.host
    }

    func body(content: Content) -> some View {
        content
            .alert("Close this tab?", isPresented: presentation(of: .keepOrEndCLI)) {
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
            .alert("Close this terminal?", isPresented: presentation(of: .closePlainTerminal)) {
                Button("Close terminal", role: .destructive) { closeTab(endingTmuxSession: true) }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { closingSessionID = nil }
            } message: {
                Text("The shell and anything still running in it will stop.")
            }
            // Only the two dialogs above show the checkbox: a modifier applies to the dialogs it wraps.
            .dialogSuppressionToggle("Don't ask again", isSuppressed: $savesCloseChoice)
            .alert("End this CLI session?", isPresented: presentation(of: .endCLI)) {
                Button("End session", role: .destructive) { closeTab(endingTmuxSession: true) }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { closingSessionID = nil }
            } message: {
                Text("The terminal process will stop. Sessions saved by the CLI will appear in the project list after refresh.")
            }
            .dismissesOnClickOutside(item: $closingSessionID)
            .onChange(of: closingSessionID) { _, newClosingSessionID in
                if newClosingSessionID == nil { savesCloseChoice = false }
            }
    }

    /// Shows `dialog` while a tab waits to close and it is the dialog for that tab.
    private func presentation(of dialog: ClosingDialog) -> Binding<Bool> {
        Binding(
            get: { closingDialog == dialog },
            set: { isPresented in if !isPresented { closingSessionID = nil } }
        )
    }

    /// SwiftUI sets the checkbox's binding before it runs the button's action, so the choice is saved here.
    private func closeTab(endingTmuxSession: Bool) {
        if let closingSessionID {
            if savesCloseChoice {
                switch closingDialog {
                case .keepOrEndCLI:
                    tabCloseChoiceSettingsStore.setChoice(endingTmuxSession ? .endSession : .keepRunning)
                case .closePlainTerminal:
                    plainTerminalCloseChoiceSettingsStore.setChoice(.closeWithoutAsking)
                case .endCLI, nil:
                    break
                }
            }
            store.closeTerminal(closingSessionID, endingTmuxSession: endingTmuxSession)
        }
        closingSessionID = nil
    }
}
