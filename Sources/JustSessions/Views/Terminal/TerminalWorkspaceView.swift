import SwiftUI

struct TerminalWorkspaceView: View {
    @ObservedObject var session: TerminalSession
    let projectDisplayName: String
    /// Named once SSH hosts are added, whichever host the tab runs on.
    let hostDisplayName: String?
    /// On screen, as the selected tab or docked to a pane.
    let isVisible: Bool
    /// Holding the keyboard: visible and in the focused pane.
    let isFocused: Bool
    /// Called when a click inside the terminal takes the keyboard.
    var onFocus: (() -> Void)?
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ThemePalette.contentSurface)

            ThemeDivider()
            EmbeddedTerminalView(session: session, isVisible: isVisible, isFocused: isFocused, onFocus: onFocus)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
