import SwiftUI

/// The Help tab: the tour and the guide, how the window works, SSH host setup, what to check when a session is
/// missing, and keyboard shortcuts.
struct HelpSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HelpTourSection()
            HelpFeatureOverview()
            HelpRemoteHostSection()
            HelpTroubleshootingSection()
            HelpKeyboardShortcutsSection()
        }
        .foregroundStyle(ThemePalette.ink)
        .textSelection(.enabled)
    }
}
