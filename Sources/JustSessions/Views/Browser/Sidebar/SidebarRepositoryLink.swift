import SwiftUI

struct SidebarRepositoryLink: View {
    var body: some View {
        Link(destination: AppLinks.githubRepositoryURL) {
            Label {
                Text("GitHub")
            } icon: {
                GitHubMark().frame(width: 16, height: 16)
            }
            .labelStyle(.iconOnly)
            .frame(width: 26, height: 30)
            .contentShape(Rectangle())
        }
        .help("Open JustSessions on GitHub")
        .accessibilityLabel("Open JustSessions on GitHub")
    }
}
