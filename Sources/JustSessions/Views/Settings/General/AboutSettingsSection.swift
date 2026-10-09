import SwiftUI

/// The bottom of General: the app and macOS versions with software updates, then where to send feedback and find
/// JustSessions online.
struct AboutSettingsSection: View {
    let onCheckForUpdates: () -> Void
    private let environment = FeedbackEnvironment.current
    @Environment(\.showAppWideSheet) private var showAppWideSheet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About JustSessions")
                        .font(.subheadline.weight(.medium))
                    Text(verbatim: environment.summary)
                        .font(.caption)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Button("Check for updates", action: onCheckForUpdates)
                        .buttonStyle(QuietBorderedButtonStyle())
                        .accessibilityIdentifier("settings.checkForUpdates")
                    Button("Release notes") { showAppWideSheet(.releaseNotes) }
                        .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
                        .accessibilityIdentifier("settings.showReleaseNotes")
                }
            }
            AboutLinksRow(environment: environment)
        }
    }
}
