import SwiftUI

/// One line: adding an SSH host, then settings, updates, and help as icons.
struct SidebarFooter: View {
    let onAddRemoteHost: () -> Void
    let onCheckForUpdates: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            SidebarAddRemoteHostButton(action: onAddRemoteHost)
            Spacer(minLength: 4)
            SidebarSettingsButton()
            checkForUpdatesButton
            SidebarHelpButton()
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
    }

    private var checkForUpdatesButton: some View {
        Button(action: onCheckForUpdates) {
            Label("Update", systemImage: "arrow.down.circle")
                .labelStyle(.iconOnly)
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
        }
        .help("Check for updates")
        .accessibilityLabel("Check for updates")
    }
}
