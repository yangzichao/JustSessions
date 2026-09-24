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
                    Label("Sessions", systemImage: "square.stack")
                }
                .buttonStyle(.bordered)
                .tint(store.selectedTerminalID == nil ? .accentColor : nil)
                .accessibilityLabel("Show sessions")

                ForEach(store.terminalSessions) { session in
                    terminalTab(session)
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

    private func terminalTab(_ session: TerminalSession) -> some View {
        HStack(spacing: 2) {
            Button {
                store.selectTerminal(session.id)
            } label: {
                HStack(spacing: 6) {
                    TerminalStatusIndicator(session: session)
                    Text(session.displayTitle)
                        .lineLimit(1)
                        .frame(maxWidth: 180)
                }
            }
            .buttonStyle(.bordered)
            .tint(store.selectedTerminalID == session.id ? .accentColor : nil)
            .help("Show \(session.displayTitle)")

            Button {
                closingSessionID = session.id
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("End and close this terminal")
            .accessibilityLabel("Close \(session.displayTitle)")
        }
    }
}
