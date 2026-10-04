import SwiftUI

/// Above a tab's terminal once its CLI has ended: how it ended and, for a remote tab, a way to connect again.
struct TerminalEndedBar: View {
    let exitCode: Int32?
    let onReconnect: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let exitCode { Text("Exited (\(exitCode))") }
                else { Text("Ended") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
            if let onReconnect {
                Button("Reconnect", systemImage: "arrow.triangle.2.circlepath", action: onReconnect)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Connect again; a CLI still running in tmux on the host is reattached")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 32)
        .background(ThemePalette.contentSurface)
    }
}
