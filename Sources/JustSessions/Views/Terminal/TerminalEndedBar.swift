import SwiftUI

/// Above a tab's terminal once its CLI has ended: how it ended and, for a remote tab, a way to check the host, as
/// when its session failed to resume, and to connect again. When the host's heading warns of a problem, or the CLI
/// ended with an error right after it started, the bar says so and Check host is its main button, so the check is
/// found where the failure shows rather than only in the sidebar. A remote tab whose connection dropped says it
/// reconnects on its own while it waits for its host; see `RemoteTabReconnector`.
struct TerminalEndedBar: View {
    let exitCode: Int32?
    let isWaitingToReconnect: Bool
    /// See `TerminalSession.endedWithErrorSoonAfterStarting`.
    let endedWithErrorSoonAfterStarting: Bool
    /// What the remote host's heading warns of; see `ConversationStore.hostCheckProblemMessage(on:)`.
    let hostProblem: String?
    let onCheckHost: (() -> Void)?
    let onReconnect: (() -> Void)?

    /// Whether the bar points at Check host, with it as its main button.
    var leadsToCheckHost: Bool {
        onCheckHost != nil && (hostProblem != nil || endedWithErrorSoonAfterStarting)
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                endedText
                    .fixedSize()
                if onCheckHost != nil, let hostProblem {
                    // Cut short to the bar's width; its tooltip has all of it.
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ThemePalette.warning)
                        Text(verbatim: hostProblem)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .help(hostProblem)
                }
            }
            .font(ThemeFont.caption)
            .foregroundStyle(ThemePalette.secondaryText)
            Spacer(minLength: 0)
            if let onCheckHost {
                if leadsToCheckHost {
                    checkHostButton(onCheckHost).buttonStyle(ThemeProminentButtonStyle())
                } else {
                    checkHostButton(onCheckHost).buttonStyle(QuietBorderedButtonStyle())
                }
            }
            if let onReconnect {
                Button("Reconnect", systemImage: "arrow.triangle.2.circlepath", action: onReconnect)
                    .buttonStyle(QuietBorderedButtonStyle())
                    .controlSize(.small)
                    .fixedSize()
                    .help("Connect again; a CLI or shell still running in tmux on the host is reattached")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: InterfaceScale.points(32))
        .background(ThemePalette.contentSurface)
    }

    private func checkHostButton(_ action: @escaping () -> Void) -> some View {
        Button("Check host", systemImage: "stethoscope", action: action)
            .controlSize(.small)
            .fixedSize()
            .help("Check what on the host could have ended this tab, such as its CLI or its folder")
    }

    @ViewBuilder private var endedText: some View {
        if isWaitingToReconnect {
            Text("Connection lost. Reconnecting…")
        } else if let exitCode {
            if endedWithErrorSoonAfterStarting { Text("Exited (\(exitCode)) right after starting") }
            else { Text("Exited (\(exitCode))") }
        } else {
            Text("Ended")
        }
    }
}
