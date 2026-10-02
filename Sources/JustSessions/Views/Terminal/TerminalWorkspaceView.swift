import SwiftUI

struct TerminalWorkspaceView: View {
    @ObservedObject var session: TerminalSession
    let projectDisplayName: String
    /// Named once SSH hosts are added, whichever host the tab runs on.
    let hostDisplayName: String?
    let isActive: Bool
    /// Shown for a remote tab whose connection ended.
    let onReconnect: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.displayTitle).font(.headline).lineLimit(1)
                    Text([projectDisplayName, hostDisplayName, session.provider?.rawValue ?? "Terminal", session.action?.displayName]
                        .compactMap { $0 }
                        .joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if session.hasExited {
                    Group {
                        if let exitCode = session.exitCode { Text("Exited (\(exitCode))") }
                        else { Text("Ended") }
                    }
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
}
