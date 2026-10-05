import SwiftUI

/// The Help & feedback tab: the tour and the guide, how the window works, SSH host setup, what to check when a
/// session is missing, feedback, and keyboard shortcuts.
struct HelpAndFeedbackSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HelpTourSection()
            HelpFeatureOverview()
            HelpRemoteHostSection()
            HelpTroubleshootingSection()
            HelpFeedbackSection()
            HelpKeyboardShortcutsSection()
        }
        .foregroundStyle(ThemePalette.ink)
        .textSelection(.enabled)
    }
}
