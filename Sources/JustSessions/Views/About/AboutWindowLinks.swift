import SwiftUI

/// The website, the source code, and what changed in each release.
struct AboutWindowLinks: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Link("Website ↗", destination: AppLinks.websiteURL)
                .help("Open the JustSessions website")
                .accessibilityIdentifier("about.website")
            Link("GitHub ↗", destination: AppLinks.gitHubRepositoryURL)
                .help("Open the source code on GitHub")
                .accessibilityIdentifier("about.gitHub")
            Link("Release notes ↗", destination: AppLinks.releaseNotesURL)
                .help("Open the release notes on the website")
                .accessibilityIdentifier("about.releaseNotes")
        }
        .font(.system(size: 12))
        .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
    }
}
