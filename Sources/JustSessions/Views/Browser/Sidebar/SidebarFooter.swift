import SwiftUI

struct SidebarFooter: View {
    let onAddRemoteHost: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            SidebarAddRemoteHostButton(action: onAddRemoteHost)
                .onboardingTourStop(.sshHosts)
            Spacer(minLength: 4)
            SidebarSettingsButton()
        }
        .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 6))
        .foregroundStyle(ThemePalette.ink)
        .font(ThemeFont.callout)
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
    }
}
