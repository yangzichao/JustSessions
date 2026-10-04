import SwiftUI

/// Host actions sit above the permanent app settings and support controls.
struct SidebarFooter: View {
    let archivedProjectCount: Int
    let onShowArchivedProjects: () -> Void
    let onAddRemoteHost: () -> Void
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if archivedProjectCount > 0 {
                Button(action: onShowArchivedProjects) {
                    Label("Archived projects (\(archivedProjectCount))\u{2026}", systemImage: "archivebox")
                }
                .help("Restore archived projects to the sidebar")
                .frame(height: 28)
            }
            SidebarAddRemoteHostButton(action: onAddRemoteHost)
                .frame(height: 28)

            HStack(spacing: 8) {
                SidebarSettingsLink()
                checkForUpdatesButton
                SidebarHelpButton()
                SidebarWebsiteLink()
            }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
