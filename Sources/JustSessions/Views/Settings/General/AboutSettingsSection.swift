import SwiftUI

struct AboutSettingsSection: View {
    let onCheckForUpdates: () -> Void
    private let environment = FeedbackEnvironment.current
    @Environment(\.showAppWideSheet) private var showAppWideSheet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About JustSessions")
                        .font(ThemeFont.heading)
                    Text(verbatim: environment.summary)
                        .font(ThemeFont.caption)
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
