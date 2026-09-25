import SwiftUI

struct TerminalWorkspaceView: View {
    @ObservedObject var session: TerminalSession
    let projectDisplayName: String
    let isActive: Bool
    /// Shown for a remote tab whose connection ended.
    let onReconnect: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.displayTitle).font(.headline).lineLimit(1)
                    Text("\(projectDisplayName) · \(session.provider.rawValue) · \(actionName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if session.hasExited {
                    Text(session.exitCode.map { "Exited (\($0))" } ?? "Ended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let onReconnect {
                        Button("Reconnect", systemImage: "arrow.triangle.2.circlepath", action: onReconnect)
                            .buttonStyle(.bordered)
                            .help("Connect again; a CLI still running in tmux on the host is reattached")
                    }
                }
                Button {
                    session.copySelection()
                } label: {
                    Label("Copy selection", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(!session.hasSelection)
                .help("Hold Shift while dragging to select terminal text, then copy it (⌘C)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ThemePalette.contentSurface)

            ThemeDivider()
            EmbeddedTerminalView(session: session, isActive: isActive)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var actionName: String {
        switch session.action {
        case .new: "New"
        case .resume: "Resume"
        case .branch: "Branch"
        }
    }
}
