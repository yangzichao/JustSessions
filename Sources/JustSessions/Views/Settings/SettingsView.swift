import SwiftUI

struct SettingsView: View {
    @Binding var selectedTab: SettingsTab
    let hosts: [SessionHost]
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
    let terminalOptionKeyStore: TerminalOptionKeyStore
    let notificationSettingsStore: SessionNotificationSettingsStore
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ThemeSegmentedPicker(
                "Settings",
                selection: Binding(
                    get: { selectedTab.switcherTab },
                    set: { selectedTab = $0 }
                ),
                segments: SettingsTab.switcherTabs.map { tab in
                    ThemeSegment(value: tab, title: Text(tab.title))
                }
            )
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
                        terminalEngineStore: terminalEngineStore,
                        terminalOptionKeyStore: terminalOptionKeyStore
                    )
                case .permissions:
                    PermissionsSettingsView()
                case .help:
                    HelpSettingsView()
                case .releaseNotes:
                    ReleaseNotesSettingsView(onShowGeneral: { selectedTab = .general })
                }
            }
            .id(selectedTab)
        }
        .background(ThemePalette.contentSurface)
    }
}
