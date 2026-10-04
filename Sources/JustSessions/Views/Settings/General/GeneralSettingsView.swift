import SwiftUI

/// The General tab of Settings: interface language, what the app does at launch, when it notifies you, and a link to
/// the website.
struct GeneralSettingsView: View {
    @ObservedObject var languageStore: AppLanguageStore
    @ObservedObject var tabReopeningSettingsStore: TabReopeningSettingsStore
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

            Text("At launch")
                .font(.subheadline.weight(.medium))
            Toggle("Reopen the tabs that were open when JustSessions quit", isOn: Binding(
                get: { tabReopeningSettingsStore.reopensTabsAtLaunch },
                set: { tabReopeningSettingsStore.setReopensTabsAtLaunch($0) }
            ))
            Text("A CLI still running in tmux reattaches. Any other tab, such as after a restart of your Mac, resumes its session when you select it. Plain terminals open a new shell in their folder.")
                .font(.caption)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ThemeDivider()

            NotificationSettingsSection(settingsStore: notificationSettingsStore)

            ThemeDivider()

            Link("JustSessions website ↗", destination: AppLinks.websiteURL)
                .help("Open the JustSessions website")
        }
        .padding(24)
        .frame(width: 540, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        // The window fits the tab, but a taller one shows the theme's surface below it, not the system's tab box.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
