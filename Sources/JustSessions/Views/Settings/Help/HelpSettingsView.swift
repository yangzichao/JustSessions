import SwiftUI

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
