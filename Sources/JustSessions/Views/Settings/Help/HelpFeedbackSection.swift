import SwiftUI

/// Feedback in Help: a GitHub issue or an email, each started with this Mac's app and macOS versions, which show
/// below the links.
struct HelpFeedbackSection: View {
    private let environment = FeedbackEnvironment.current

    var body: some View {
        HelpSection(title: "Feedback") {
            Text("Found a bug, or missing something? Open a GitHub issue or send an email. Both start with your versions filled in.")
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Link("Open a GitHub issue ↗", destination: FeedbackLinks.gitHubIssueURL(for: environment))
                    .help("Create a GitHub issue")
                    .accessibilityIdentifier("help.github-issue")
                Link("Email feedback ↗", destination: FeedbackLinks.emailURL(for: environment))
                    .help("Email feedback")
                    .accessibilityIdentifier("help.email-feedback")
            }
            .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
            Text(verbatim: environment.summary)
                .font(.caption)
                .foregroundStyle(ThemePalette.secondaryText)
        }
    }
}
