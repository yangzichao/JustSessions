import SwiftUI

struct SidebarHostConnectButton: View {
    let host: SessionHost
    let isLoggingIn: Bool
    let failureMessage: String?
    let action: () -> Void

    var body: some View {
        if isLoggingIn {
            ProgressView()
                .controlSize(.mini)
                .frame(height: InterfaceScale.points(20))
                .accessibilityLabel(Text("Connecting to \(host.displayName)…"))
        } else {
            Button("Connect…", action: action)
                .font(ThemeFont.caption.weight(.semibold))
                .foregroundStyle(ThemePalette.ink)
                .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 4, verticalPadding: 2, cornerRadius: .small))
                .fixedSize()
                .help(failureMessage ?? AppLocalization.string("Log in to \(host.displayName)"))
                .accessibilityIdentifier(host.sshDestination.map { "sidebar.connectHost.ssh.\($0)" } ?? "")
        }
    }
}
