import SwiftUI

/// App-wide settings stay available even when no terminal tab is open.
struct SidebarSettingsLink: View {
    var body: some View {
        SettingsLink {
            Label("Settings", systemImage: "gearshape")
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .help("Settings (⌘,)")
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("sidebar.settings")
    }
}
