import SwiftUI

/// The bottom of General: the app and macOS versions with software updates, then where to send feedback and find
/// JustSessions online.
struct AboutSettingsSection: View {
    let onCheckForUpdates: () -> Void
    private let environment = FeedbackEnvironment.current

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
                Button("Check for updates", action: onCheckForUpdates)
                    .buttonStyle(QuietBorderedButtonStyle())
                    .accessibilityIdentifier("settings.checkForUpdates")
            }
            AboutLinksRow(environment: environment)
            Text("Feedback and issues start with these versions filled in.")
                .font(.caption)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
