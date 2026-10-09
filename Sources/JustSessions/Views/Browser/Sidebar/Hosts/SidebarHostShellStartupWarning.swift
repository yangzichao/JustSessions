import SwiftUI

/// The warning after an SSH host's name while its shell startup keeps CLIs from starting there; see
/// `RemoteShellStartupCheck`. Its tooltip says where the startup stopped, and clicking it opens the user guide's
/// section on what to change.
struct SidebarHostShellStartupWarning: View {
    let host: SessionHost
    let stoppedAt: String?

    var body: some View {
        Button {
            NSWorkspace.shared.open(AppLinks.userGuideSSHShellStartupURL)
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ThemePalette.warning)
                .frame(width: 14, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(message)
        .accessibilityLabel(message)
    }

    private var message: String {
        if let stoppedAt {
            AppLocalization.string(
                "Sessions on \(host.displayName) open a shell instead of their CLI, because its shell startup runs \(stoppedAt) first. Click for how to fix it."
            )
        } else {
            AppLocalization.string(
                "Sessions on \(host.displayName) open a shell instead of their CLI, because its shell startup starts another program first. Click for how to fix it."
            )
        }
    }
}
