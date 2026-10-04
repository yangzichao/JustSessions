import SwiftUI

/// The General tab of Settings: interface language, what the app does at startup, when it notifies you, and a link to
/// the website.
struct GeneralSettingsView: View {
    @ObservedObject var languageStore: AppLanguageStore
    let tabReopeningSettingsStore: TabReopeningSettingsStore
    let launchAtLoginSettingsStore: LaunchAtLoginSettingsStore
    let notificationSettingsStore: SessionNotificationSettingsStore

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

            NotificationSettingsSection(settingsStore: notificationSettingsStore)

            ThemeDivider()

            Link("JustSessions website ↗", destination: AppLinks.websiteURL)
                .help("Open the JustSessions website")
        }
    }
}
