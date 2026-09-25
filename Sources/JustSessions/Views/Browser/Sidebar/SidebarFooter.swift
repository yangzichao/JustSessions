import SwiftUI

/// Adding an SSH host and update checks, kept small at the bottom of the sidebar.
struct SidebarFooter: View {
    let onAddRemoteHost: () -> Void
    let onCheckForUpdates: () -> Void

    var body: some View {
        // A sidebar too narrow for both titles drops Update's, so "Add SSH host…" is never cut off.
        ViewThatFits(in: .horizontal) {
            footerRow(updateButton: checkForUpdatesButton.labelStyle(.titleAndIcon))
            footerRow(updateButton: checkForUpdatesButton.labelStyle(.iconOnly))
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
        .padding(.horizontal, 16)
        .frame(height: 36)
    }

    private func footerRow(updateButton: some View) -> some View {
        HStack(spacing: 0) {
            SidebarAddRemoteHostButton(action: onAddRemoteHost)
            Spacer(minLength: 12)
            updateButton
        }
    }

    private var checkForUpdatesButton: some View {
        Button(action: onCheckForUpdates) {
            Label("Update", systemImage: "arrow.down.circle")
        }
        .help("Check for updates")
    }
}
