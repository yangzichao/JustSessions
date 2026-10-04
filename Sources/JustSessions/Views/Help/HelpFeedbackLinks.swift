import SwiftUI

struct HelpFeedbackLinks: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Feedback:")
                .foregroundStyle(ThemePalette.secondaryText)
            Link("GitHub issue ↗", destination: AppLinks.createGitHubIssueURL)
                .help("Create a GitHub issue")
                .accessibilityIdentifier("help.github-issue")
            Text("·")
                .foregroundStyle(ThemePalette.secondaryText)
            Link("Email ↗", destination: AppLinks.feedbackEmailURL)
                .help("Email feedback")
                .accessibilityIdentifier("help.email-feedback")
        }
    }
}
