import SwiftUI

/// Feedback first, written in Settings or as a GitHub issue, each sent with `environment`'s versions; then the website
/// and the source code.
struct AboutLinksRow: View {
    let environment: FeedbackEnvironment
    @Environment(\.showAppWideSheet) private var showAppWideSheet

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Button("Send feedback") { showAppWideSheet(.feedback) }
                .help("Write to the developer from here")
                .accessibilityIdentifier("settings.sendFeedback")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Link("Report an issue ↗", destination: FeedbackLinks.gitHubIssueURL(for: environment))
                    .help("Open a new issue on GitHub")
                    .accessibilityIdentifier("settings.reportIssue")
                HelpPopoverButton(
                    title: "Feedback",
                    explanation: "Feedback and issues are sent with these versions."
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
