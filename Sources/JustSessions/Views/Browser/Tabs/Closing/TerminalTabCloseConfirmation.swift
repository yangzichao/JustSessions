import SwiftUI

/// Return closes the tab, and Escape cancels. The dialogs are alerts rather than confirmation dialogs: on macOS, a
/// confirmation dialog gives no button Return.
struct TerminalTabCloseConfirmation: ViewModifier {
    let store: ConversationStore
    @Binding var closingSessionID: UUID?
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    let plainTerminalCloseChoiceSettingsStore: PlainTerminalCloseChoiceSettingsStore
    @State private var savesCloseChoice = false

    private enum ClosingDialog {
        case keepOrEndCLI
        case closePlainTerminal
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
                Button("Keep running") { closeTab(endingTmuxSession: false) }
                    .keyboardShortcut(.defaultAction)
                Button("End session", role: .destructive) { closeTab(endingTmuxSession: true) }
                Button("Cancel", role: .cancel) { closingSessionID = nil }
            } message: {
                if let closingTabTmuxHost {
                    Text(
                        "Keep running leaves the CLI running in tmux on \(closingTabTmuxHost.nameInSentence); click the session to reattach. End session stops it."
                    )
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
            .dialogSuppressionToggle(dontAskAgainLabel, isSuppressed: $savesCloseChoice)
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

    private var dontAskAgainLabel: Text {
        if let closingTabTmuxHost {
            Text("Don't ask again on \(closingTabTmuxHost.nameInSentence)")
        } else {
            Text("Don't ask again")
        }
    }

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
                    if let closingTabTmuxHost {
                        tabCloseChoiceSettingsStore.setChoice(endingTmuxSession ? .endSession : .keepRunning, for: closingTabTmuxHost)
                    }
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
