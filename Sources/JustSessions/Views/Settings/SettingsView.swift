import SwiftUI

/// Settings (⌘,): language, launch, notifications, updates, and feedback; how the app and its terminals look; what macOS
/// allows the app; and help. A switcher at the top picks the page; release notes open from General.
struct SettingsView: View {
    @Binding var selectedTab: SettingsTab
    /// This Mac and the window's SSH hosts, for settings each host has its own of.
    let hosts: [SessionHost]
    /// The window's store, for settings it keeps, such as the CLIs whose sessions are hidden.
    let conversationStore: ConversationStore
    let languageStore: AppLanguageStore
    let tabReopeningSettingsStore: TabReopeningSettingsStore
    let launchAtLoginSettingsStore: LaunchAtLoginSettingsStore
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    let plainTerminalCloseChoiceSettingsStore: PlainTerminalCloseChoiceSettingsStore
    let fileLinkClickSettingsStore: FileLinkClickSettingsStore
    let editorStore: ExternalEditorStore
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore
    let terminalEngineStore: TerminalEngineStore
    let notificationSettingsStore: SessionNotificationSettingsStore
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ThemeSegmentedPicker("Settings", selection: Binding(
                get: { selectedTab.switcherTab },
                set: { selectedTab = $0 }
            ), segments: SettingsTab.switcherTabs.map { tab in
                ThemeSegment(value: tab, title: Text(tab.title))
            })
            .fixedSize()
            .padding(.vertical, 12)

            ThemeDivider()

            SettingsTabPage {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(
                        hosts: hosts,
                        conversationStore: conversationStore,
                        languageStore: languageStore,
                        tabReopeningSettingsStore: tabReopeningSettingsStore,
                        launchAtLoginSettingsStore: launchAtLoginSettingsStore,
                        tabCloseChoiceSettingsStore: tabCloseChoiceSettingsStore,
                        plainTerminalCloseChoiceSettingsStore: plainTerminalCloseChoiceSettingsStore,
                        fileLinkClickSettingsStore: fileLinkClickSettingsStore,
                        editorStore: editorStore,
                        notificationSettingsStore: notificationSettingsStore,
                        onCheckForUpdates: onCheckForUpdates
                    )
                case .appearance:
                    AppearanceSettingsView(
                        appAppearanceStore: appAppearanceStore,
                        appThemeStore: appThemeStore,
                        terminalAppearanceStore: terminalAppearanceStore,
                        terminalEngineStore: terminalEngineStore
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
