import SwiftUI

struct SidebarHostSignInButton: View {
    let host: SessionHost
    let isSigningIn: Bool
    let action: () -> Void

    var body: some View {
        if isSigningIn {
            ProgressView()
                .controlSize(.mini)
                .frame(height: InterfaceScale.points(20))
                .accessibilityLabel(Text("Signing in on \(host.displayName)…"))
        } else {
            Button("Sign in…", action: action)
                .font(ThemeFont.caption.weight(.semibold))
                .foregroundStyle(ThemePalette.ink)
                .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 4, verticalPadding: 2, cornerRadius: .small))
                .fixedSize()
                .help(AppLocalization.string("Your sign-in command on \(host.displayName) is due"))
                .accessibilityIdentifier(host.sshDestination.map { "sidebar.signInHost.ssh.\($0)" } ?? "")
        }
    }
}
