import SwiftUI

/// App-wide settings stay available even when no terminal tab is open.
struct SidebarSettingsButton: View {
    @Environment(\.showAppWideSheet) private var showAppWideSheet

    var body: some View {
        Button {
            showAppWideSheet(.settings)
        } label: {
            Label("Settings", systemImage: "gearshape")
                .labelStyle(.titleAndIcon)
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .help("Settings (⌘,)")
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("sidebar.settings")
    }
}
