import SwiftUI

/// Email and a GitHub issue, each started with `environment`'s versions, for feedback that needs a thread or an
/// attachment, or when the form can't send.
struct FeedbackAlternativeLinks: View {
    let environment: FeedbackEnvironment

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("Prefer email or GitHub?")
                .foregroundStyle(ThemePalette.secondaryText)
            Link("Email us ↗", destination: FeedbackLinks.emailURL(for: environment))
                .help(AppLinks.feedbackEmailAddress)
                .accessibilityIdentifier("feedback.email")
            Link("Report an issue ↗", destination: FeedbackLinks.gitHubIssueURL(for: environment))
                .help("Open a new issue on GitHub")
                .accessibilityIdentifier("feedback.reportIssue")
        }
        .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
    }
}
