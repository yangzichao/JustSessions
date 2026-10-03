import SwiftUI

struct SidebarWebsiteLink: View {
    var body: some View {
        Link(destination: AppLinks.websiteURL) {
            Label("Website", systemImage: "globe")
                .labelStyle(.iconOnly)
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
        }
        .help("Open the JustSessions website")
        .accessibilityLabel("Open the JustSessions website")
    }
}
