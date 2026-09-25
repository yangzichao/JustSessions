import SwiftUI

/// Update checks, kept small at the bottom of the sidebar.
struct SidebarFooter: View {
    let onCheckForUpdates: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
