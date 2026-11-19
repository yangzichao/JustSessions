import SwiftUI

struct TerminalEndedBar: View {
    let exitCode: Int32?
    let isWaitingToReconnect: Bool
    let endedWithErrorSoonAfterStarting: Bool
    let hostProblem: String?
    let onCheckHost: (() -> Void)?
    let onReconnect: (() -> Void)?

    var leadsToCheckHost: Bool {
        onCheckHost != nil && (hostProblem != nil || endedWithErrorSoonAfterStarting)
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                endedText
                    .fixedSize()
                if onCheckHost != nil, let hostProblem {
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
            if endedWithErrorSoonAfterStarting { Text("Exited (\(exitCode)) right after starting") } else { Text("Exited (\(exitCode))") }
        } else {
            Text("Ended")
        }
    }
}
