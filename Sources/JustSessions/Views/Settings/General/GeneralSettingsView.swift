import SwiftUI

/// The General tab of Settings: interface language, what the app does at startup, what closing a tab does, whether the
/// sidebar lists subagents, and when it notifies you; then the installed versions, software updates, and feedback.
struct GeneralSettingsView: View {
    @ObservedObject var languageStore: AppLanguageStore
    let tabReopeningSettingsStore: TabReopeningSettingsStore
    let launchAtLoginSettingsStore: LaunchAtLoginSettingsStore
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    let notificationSettingsStore: SessionNotificationSettingsStore
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Interface language", selection: Binding(
                get: { languageStore.language },
                set: { languageStore.setLanguage($0) }
            )) {
                ForEach(languageStore.choices) { language in
                    if language == .followSystem {
                        Text("Follow System").tag(language)
                    } else {
                        Text(verbatim: language.nativeName).tag(language)
                    }
                }
            }
            .accessibilityIdentifier("settings.interfaceLanguage")

            ThemeDivider()

            StartupSettingsSection(
                launchAtLoginSettingsStore: launchAtLoginSettingsStore,
                tabReopeningSettingsStore: tabReopeningSettingsStore
            )

            ThemeDivider()

            TabClosingSettingsSection(settingsStore: tabCloseChoiceSettingsStore)

            ThemeDivider()

            SidebarSettingsSection()

            ThemeDivider()

            NotificationSettingsSection(settingsStore: notificationSettingsStore)

            ThemeDivider()

            AboutSettingsSection(onCheckForUpdates: onCheckForUpdates)
        }
        .toggleStyle(ThemedCheckboxToggleStyle())
    }
}
