import SwiftUI

struct TerminalWorkspaceView: View {
    @ObservedObject var store: ConversationStore
    @ObservedObject var session: TerminalSession
    @State private var closingSessionID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    store.selectTerminal(nil)
                } label: {
                    Label("Sessions", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.displayTitle).font(.headline).lineLimit(1)
                    Text("\(session.conversation.projectName) · \(session.conversation.provider.rawValue) · \(actionName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if session.hasExited {
                    Text(session.exitCode.map { "Exited (\($0))" } ?? "Ended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Close terminal") { closingSessionID = session.id }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(store.terminalSessions) { terminalSession in
                        HStack(spacing: 2) {
                            Button {
                                store.selectTerminal(terminalSession.id)
                            } label: {
                                Text(terminalSession.displayTitle)
                                    .lineLimit(1)
                                    .frame(maxWidth: 180)
                            }
                            .buttonStyle(.bordered)
                            .tint(terminalSession.id == session.id ? .accentColor : nil)
                            Button {
                                closingSessionID = terminalSession.id
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.borderless)
                            .help("End and close this terminal")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
            }
            Divider()

            EmbeddedTerminalView(session: session)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .confirmationDialog("End this CLI session?", isPresented: Binding(
            get: { closingSessionID != nil },
            set: { if !$0 { closingSessionID = nil } }
        )) {
            Button("End session", role: .destructive) {
                if let closingSessionID { store.closeTerminal(closingSessionID) }
                closingSessionID = nil
            }
        } message: {
            Text("The terminal process will stop. You can resume the conversation again from the project list.")
        }
    }

    private var actionName: String {
        switch session.action {
        case .resume: "Resume"
        case .branch: "Branch"
        }
    }
}
