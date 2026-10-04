import SwiftUI

/// Help stays available in every sidebar state.
struct SidebarHelpButton: View {
    @Environment(\.showAppWideSheet) private var showAppWideSheet

    var body: some View {
        Button {
            showAppWideSheet(.help)
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
