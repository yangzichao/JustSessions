import SwiftUI

struct WorkspaceTabBar: View {
    @ObservedObject var store: ConversationStore
    let onRenameConversation: (Conversation) -> Void
    @State private var closingSessionID: UUID?

    /// The host whose tmux can keep the closing tab's CLI running, when closing can leave it running.
    private var closingTabTmuxHost: SessionHost? {
        store.terminalSessions.first { $0.id == closingSessionID && $0.canKeepCLIRunningAfterClose }?.host
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                Button {
                    store.selectTerminal(nil)
                } label: {
                    Label("Preview", systemImage: "text.bubble")
                }
                .buttonStyle(WorkspaceTabButtonStyle(isSelected: store.selectedTerminalID == nil))
                .help("Show the selected session's conversation")
                .accessibilityLabel("Show session preview")

                ForEach(store.terminalSessions) { session in
                    TerminalTab(
                        session: session,
                        isSelected: store.selectedTerminalID == session.id,
                        onSelect: { store.selectTerminal(session.id) },
                        onRename: onRenameConversation,
                        onClose: { closingSessionID = session.id }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(ThemePalette.contentSurface.ignoresSafeArea())
        .confirmationDialog(closingTabTmuxHost == nil ? "End this CLI session?" : "Close this tab?", isPresented: Binding(
            get: { closingSessionID != nil },
            set: { if !$0 { closingSessionID = nil } }
        )) {
            if closingTabTmuxHost != nil {
                Button("Keep running") {
                    if let closingSessionID { store.closeTerminal(closingSessionID, endingTmuxSession: false) }
                    closingSessionID = nil
                }
            }
            Button("End session", role: .destructive) {
                if let closingSessionID { store.closeTerminal(closingSessionID, endingTmuxSession: true) }
                closingSessionID = nil
            }
        } message: {
            if let closingTabTmuxHost {
                Text("Keep running leaves the CLI running in tmux on \(closingTabTmuxHost.nameInSentence); resume the session to reattach. End session stops it.")
            } else {
                Text("The terminal process will stop. Sessions saved by the CLI will appear in the project list after refresh.")
            }
        }
    }
}

private struct TerminalTab: View {
    @ObservedObject var session: TerminalSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: (Conversation) -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    TerminalStatusIndicator(session: session)
                    Text(session.displayTitle)
                        .lineLimit(1)
                        .frame(maxWidth: 180)
                }
            }
            .buttonStyle(WorkspaceTabButtonStyle(isSelected: isSelected))
            .help("Show \(session.displayTitle)")
            .contextMenu {
                Button("Rename", systemImage: "pencil") {
                    if let conversation = session.conversation { onRename(conversation) }
                }
                .disabled(session.conversation == nil)
                Button("End session…", systemImage: "xmark", role: .destructive, action: onClose)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("End and close this terminal")
            .accessibilityLabel("Close \(session.displayTitle)")
        }
    }
}
