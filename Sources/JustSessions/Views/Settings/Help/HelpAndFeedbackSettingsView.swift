import SwiftUI

/// The Help & feedback tab: the guide and feedback links, session basics, SSH host setup, and keyboard shortcuts.
struct HelpAndFeedbackSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Link("User guide ↗", destination: AppLinks.userGuideURL)
                    .accessibilityIdentifier("help.user-guide")
                HelpFeedbackLinks()
                Spacer(minLength: 0)
            }
            .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
            .font(.callout)

            HelpFeatureOverview()
            HelpRemoteHostSection()
            HelpKeyboardShortcutsSection()
        }
        .foregroundStyle(ThemePalette.ink)
        .textSelection(.enabled)
    }
}
