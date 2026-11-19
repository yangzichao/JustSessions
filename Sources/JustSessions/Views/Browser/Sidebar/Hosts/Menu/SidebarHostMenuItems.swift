import SwiftUI

struct SidebarHostMenuItems: View {
    let refreshStatus: HostRefreshStatus?
    let isRefreshDisabled: Bool
    let archivedProjectCount: Int
    let onAddProject: () -> Void
    let onShowArchivedProjects: () -> Void
    let onRefresh: () -> Void
    let sshHostActions: SidebarSSHHostActions?

    var body: some View {
        Button("Add project…", systemImage: "plus", action: onAddProject)
        if archivedProjectCount > 0 {
            Button(
                "Archived projects (\(archivedProjectCount))\u{2026}", systemImage: "archivebox",
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
