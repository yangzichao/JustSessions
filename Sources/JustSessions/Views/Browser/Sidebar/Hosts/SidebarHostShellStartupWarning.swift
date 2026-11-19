import SwiftUI

struct SidebarHostShellStartupWarning: View {
    let host: SessionHost
    let stoppedAt: String?

    var body: some View {
        Button {
            NSWorkspace.shared.open(AppLinks.userGuideSSHShellStartupURL)
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ThemePalette.warning)
                .frame(width: InterfaceScale.points(14), height: InterfaceScale.points(20))
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePressButtonStyle())
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
