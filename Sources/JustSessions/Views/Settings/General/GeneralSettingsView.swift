import SwiftUI

/// The General tab of Settings: interface language, what the app does at startup, what closing a tab and ⌘-clicking a
/// file link in one do, whether the sidebar lists subagents and which CLIs' sessions it lists, and when it notifies
/// you; then the installed versions, software updates, and feedback.
struct GeneralSettingsView: View {
    let hosts: [SessionHost]
    /// The window's store, which keeps the CLIs whose sessions are hidden.
    let conversationStore: ConversationStore
    @ObservedObject var languageStore: AppLanguageStore
    let tabReopeningSettingsStore: TabReopeningSettingsStore
    let launchAtLoginSettingsStore: LaunchAtLoginSettingsStore
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    let plainTerminalCloseChoiceSettingsStore: PlainTerminalCloseChoiceSettingsStore
    let fileLinkClickSettingsStore: FileLinkClickSettingsStore
    let editorStore: ExternalEditorStore
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

            TabSettingsSection(
                hosts: hosts,
                tabCloseChoiceSettingsStore: tabCloseChoiceSettingsStore,
                plainTerminalCloseChoiceSettingsStore: plainTerminalCloseChoiceSettingsStore,
                fileLinkClickSettingsStore: fileLinkClickSettingsStore,
                editorStore: editorStore
            )

            ThemeDivider()

            SidebarSettingsSection(store: conversationStore)

            ThemeDivider()

            NotificationSettingsSection(settingsStore: notificationSettingsStore)

            ThemeDivider()

            AboutSettingsSection(onCheckForUpdates: onCheckForUpdates)
        }
        .toggleStyle(ThemedCheckboxToggleStyle())
    }
}
