import SwiftUI

struct HelpFeedbackLinks: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Link("Create a GitHub issue ↗", destination: AppLinks.createGitHubIssueURL)
                .accessibilityIdentifier("help.github-issue")
            Link(destination: AppLinks.bugReportEmailURL) {
                Label("Bug report", systemImage: "envelope")
            }
            .help("Email a bug report")
            .accessibilityIdentifier("help.email-bug-report")
        }
    }
}
