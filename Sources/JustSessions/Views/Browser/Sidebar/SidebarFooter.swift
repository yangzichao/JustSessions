import SwiftUI

/// One line: adding an SSH host, then settings.
struct SidebarFooter: View {
    let onAddRemoteHost: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            SidebarAddRemoteHostButton(action: onAddRemoteHost)
            Spacer(minLength: 4)
            SidebarSettingsButton()
        }
        .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 6))
        .foregroundStyle(ThemePalette.ink)
        .font(.system(size: 12))
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
    }
}
