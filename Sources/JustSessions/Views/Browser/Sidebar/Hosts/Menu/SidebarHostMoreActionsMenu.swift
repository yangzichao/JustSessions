import SwiftUI

/// The ⋯ on a host's heading, which opens the same menu as a right-click so it can be found without one.
struct SidebarHostMoreActionsMenu: View {
    let host: SessionHost
    let menuItems: SidebarHostMenuItems

    var body: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: 4))
        .fixedSize()
        .help("More actions")
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: LocalizedStringKey {
        host == .thisMac ? "More actions for this Mac" : "More actions for \(host.displayName)"
    }
}
