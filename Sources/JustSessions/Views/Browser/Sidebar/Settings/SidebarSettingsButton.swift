import SwiftUI

struct SidebarSettingsButton: View {
    @Environment(\.showAppWideSheet) private var showAppWideSheet

    var body: some View {
        Button {
            showAppWideSheet(.settings)
        } label: {
            Label("Settings", systemImage: "gearshape")
                .labelStyle(.titleAndIcon)
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: InterfaceScale.points(30))
                .contentShape(Rectangle())
        }
        .help("Settings (⌘,)")
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("sidebar.settings")
    }
}
