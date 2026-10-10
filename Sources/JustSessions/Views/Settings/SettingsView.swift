import SwiftUI

/// Settings (⌘,): language, launch, notifications, updates, and feedback; how the app and its terminals look; what macOS
/// allows the app; and help. A switcher at the top picks the page; release notes open from General.
struct SettingsView: View {
    @Binding var selectedTab: SettingsTab
    let languageStore: AppLanguageStore
    let tabReopeningSettingsStore: TabReopeningSettingsStore
    let launchAtLoginSettingsStore: LaunchAtLoginSettingsStore
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    let plainTerminalCloseChoiceSettingsStore: PlainTerminalCloseChoiceSettingsStore
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore
    let notificationSettingsStore: SessionNotificationSettingsStore
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings", selection: Binding(
                get: { selectedTab.switcherTab },
                set: { selectedTab = $0 }
            )) {
                ForEach(SettingsTab.switcherTabs) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.vertical, 12)

            ThemeDivider()

            SettingsTabPage {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(
                        languageStore: languageStore,
                        tabReopeningSettingsStore: tabReopeningSettingsStore,
                        launchAtLoginSettingsStore: launchAtLoginSettingsStore,
                        tabCloseChoiceSettingsStore: tabCloseChoiceSettingsStore,
                        plainTerminalCloseChoiceSettingsStore: plainTerminalCloseChoiceSettingsStore,
                        notificationSettingsStore: notificationSettingsStore,
                        onCheckForUpdates: onCheckForUpdates
                    )
                case .appearance:
                    AppearanceSettingsView(
                        appAppearanceStore: appAppearanceStore,
                        appThemeStore: appThemeStore,
                        terminalAppearanceStore: terminalAppearanceStore
                    )
                case .permissions:
                    PermissionsSettingsView()
                case .help:
                    HelpSettingsView()
                case .releaseNotes:
                    ReleaseNotesSettingsView(onShowGeneral: { selectedTab = .general })
                }
            }
            // A fresh scroll position for each page.
            .id(selectedTab)
        }
        .background(ThemePalette.contentSurface)
    }
}
