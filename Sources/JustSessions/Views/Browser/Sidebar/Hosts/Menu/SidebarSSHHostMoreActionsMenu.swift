import SwiftUI

struct SidebarSSHHostMoreActionsMenu: View {
    let host: SessionHost
    let actions: SidebarSSHHostActions

    var body: some View {
        Menu {
            SidebarSSHHostMenuItems(actions: actions)
        } label: {
            Image(systemName: "ellipsis")
                .font(ThemeFont.glyph(.control, weight: .bold))
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: InterfaceScale.points(16), height: InterfaceScale.points(16))
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: .small))
        .fixedSize()
        .help("More actions")
        .accessibilityLabel("More actions for \(host.displayName)")
    }
}
