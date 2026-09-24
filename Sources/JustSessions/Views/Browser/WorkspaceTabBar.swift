import SwiftUI

struct WorkspaceTabBar: View {
    @ObservedObject var store: ConversationStore
    @State private var closingSessionID: UUID?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                Button {
                    store.selectTerminal(nil)
                } label: {
                    Label("Preview", systemImage: "text.bubble")
                }
                .buttonStyle(.bordered)
                .tint(store.selectedTerminalID == nil ? .accentColor : nil)
                .help("Show the selected session's conversation")
                .accessibilityLabel("Show session preview")

                ForEach(store.terminalSessions) { session in
                    TerminalTab(
                        session: session,
                        isSelected: store.selectedTerminalID == session.id,
                        onSelect: { store.selectTerminal(session.id) },
                        onClose: { closingSessionID = session.id }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog("End this CLI session?", isPresented: Binding(
            get: { closingSessionID != nil },
            set: { if !$0 { closingSessionID = nil } }
        )) {
            Button("End session", role: .destructive) {
                if let closingSessionID { store.closeTerminal(closingSessionID) }
                closingSessionID = nil
            }
        } message: {
            Text("The terminal process will stop. Sessions saved by the CLI will appear in the project list after refresh.")
        }
    }
}

private struct TerminalTab: View {
    @ObservedObject var session: TerminalSession
    let isSelected: Bool
    let onSelect: () -> Void
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
            .buttonStyle(.bordered)
            .tint(isSelected ? .accentColor : nil)
            .help("Show \(session.displayTitle)")

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("End and close this terminal")
            .accessibilityLabel("Close \(session.displayTitle)")
        }
    }
}
