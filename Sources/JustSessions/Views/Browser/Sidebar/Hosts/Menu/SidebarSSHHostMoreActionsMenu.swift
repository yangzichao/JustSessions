import SwiftUI

/// The ⋯ on an SSH host's heading, drawn like the heading's + and refresh button rather than a row's ⋯.
struct SidebarSSHHostMoreActionsMenu: View {
    let host: SessionHost
    let actions: SidebarSSHHostActions

    var body: some View {
        Menu {
            SidebarSSHHostMenuItems(actions: actions)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: 4))
        .fixedSize()
        .help("More actions")
        .accessibilityLabel("More actions for \(host.displayName)")
    }
}
