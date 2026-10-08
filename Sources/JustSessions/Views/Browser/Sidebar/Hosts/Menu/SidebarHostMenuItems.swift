import SwiftUI

/// A host heading's right-click menu: add a project, restore archived projects, refresh the host, and, for an SSH
/// host, its own settings; see `SidebarSSHHostMenuItems`.
struct SidebarHostMenuItems: View {
    let refreshStatus: HostRefreshStatus?
    let isRefreshDisabled: Bool
    let archivedProjectCount: Int
    let onAddProject: () -> Void
    let onShowArchivedProjects: () -> Void
    let onRefresh: () -> Void
    /// Nil for this Mac, which is always listed and whose tmux server reads no configuration.
    let sshHostActions: SidebarSSHHostActions?

    var body: some View {
        Button("Add project…", systemImage: "plus", action: onAddProject)
        if archivedProjectCount > 0 {
            Button("Archived projects (\(archivedProjectCount))\u{2026}", systemImage: "archivebox",
                   action: onShowArchivedProjects)
        }
        Divider()
        Button("Refresh", systemImage: "arrow.clockwise", action: onRefresh)
            .disabled(refreshStatus == .refreshing || isRefreshDisabled)
        if let sshHostActions {
            Divider()
            SidebarSSHHostMenuItems(actions: sshHostActions)
        }
    }
}
