import SwiftUI

/// Feedback first, by email or as a GitHub issue, each started with `environment`'s versions; then the website and
/// the source code.
struct AboutLinksRow: View {
    let environment: FeedbackEnvironment

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Link("Send us feedback ↗", destination: FeedbackLinks.emailURL(for: environment))
                .help(AppLinks.feedbackEmailAddress)
                .accessibilityIdentifier("settings.sendFeedback")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Link("Report an issue ↗", destination: FeedbackLinks.gitHubIssueURL(for: environment))
                    .help("Open a new issue on GitHub")
                    .accessibilityIdentifier("settings.reportIssue")
                HelpPopoverButton(
                    title: "Feedback",
                    explanation: "Feedback and issues start with these versions filled in."
                )
                .accessibilityIdentifier("settings.help.feedback")
            }
            Link("Website ↗", destination: AppLinks.websiteURL)
                .help("Open the JustSessions website")
                .accessibilityIdentifier("settings.website")
            Link("GitHub ↗", destination: AppLinks.gitHubRepositoryURL)
                .help("Open the source code on GitHub")
                .accessibilityIdentifier("settings.gitHub")
        }
        .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
    }
}
