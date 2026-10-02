import SwiftUI

/// Help stays available in every sidebar state.
struct SidebarHelpButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: HelpView.windowID)
        } label: {
            Label("Help", systemImage: "questionmark.circle")
                .labelStyle(.iconOnly)
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
        }
        .help("Help and remote host setup")
        .accessibilityLabel("Help")
        .accessibilityIdentifier("sidebar.help")
    }
}
