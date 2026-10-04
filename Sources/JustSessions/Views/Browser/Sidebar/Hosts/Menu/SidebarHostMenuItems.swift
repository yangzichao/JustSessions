import SwiftUI

/// A host heading's right-click menu: add a project, restore archived projects, refresh the host, or remove an SSH
/// host.
struct SidebarHostMenuItems: View {
    let refreshStatus: HostRefreshStatus?
    let isRefreshDisabled: Bool
    let archivedProjectCount: Int
    let onAddProject: () -> Void
    let onShowArchivedProjects: () -> Void
    let onRefresh: () -> Void
    /// Nil for this Mac, which is always listed.
    let onRemove: (() -> Void)?

    var body: some View {
        Button("Add project…", systemImage: "plus", action: onAddProject)
        if archivedProjectCount > 0 {
            Button("Archived projects (\(archivedProjectCount))\u{2026}", systemImage: "archivebox",
                   action: onShowArchivedProjects)
        }
        Divider()
        Button("Refresh", systemImage: "arrow.clockwise", action: onRefresh)
            .disabled(refreshStatus == .refreshing || isRefreshDisabled)
        if let onRemove {
            Divider()
            Button("Remove host", systemImage: "minus.circle", role: .destructive, action: onRemove)
        }
    }
}
