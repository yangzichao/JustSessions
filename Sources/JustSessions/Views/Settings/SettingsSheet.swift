import SwiftUI

/// Settings as a sheet on a workspace window: the tabs, then Done.
struct SettingsSheet: View {
    let onCheckForUpdates: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SettingsView(
                languageStore: .shared,
                tabReopeningSettingsStore: .shared,
                launchAtLoginSettingsStore: .shared,
                appAppearanceStore: .shared,
                appThemeStore: .shared,
                terminalAppearanceStore: .shared,
                notificationSettingsStore: .shared,
                onCheckForUpdates: onCheckForUpdates
            )
            ThemeDivider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(ThemePalette.contentSurface)
        .appLanguage(from: .shared)
    }
}
