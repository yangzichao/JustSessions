import SwiftUI

/// Remote hosts and update checks, kept small at the bottom of the sidebar.
struct SidebarFooter: View {
    @ObservedObject var store: ConversationStore
    let onManageRemoteHosts: () -> Void
    let onCheckForUpdates: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onManageRemoteHosts) {
                HStack(spacing: 5) {
                    Label("Remote", systemImage: "network")
                    if store.isSyncingRemoteHosts {
                        ProgressView().controlSize(.mini)
                    } else if store.hasRemoteHostFailure {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ThemePalette.warning)
                    }
                }
            }
            .help(store.hasRemoteHostFailure ? "A remote host could not be reached" : "Manage remote hosts")

            Spacer()

            Button(action: onCheckForUpdates) {
                Label("Update", systemImage: "arrow.down.circle")
            }
            .help("Check for updates")
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
        .padding(.horizontal, 16)
        .frame(height: 36)
    }
}
