import SwiftUI

/// The Settings window (⌘,): language, launch, and notifications; how the app and its terminals look; and what macOS
/// allows the app.
struct SettingsView: View {
    let languageStore: AppLanguageStore
    let tabReopeningSettingsStore: TabReopeningSettingsStore
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore
    let notificationSettingsStore: SessionNotificationSettingsStore

    var body: some View {
        TabView {
            SettingsTabPage {
                GeneralSettingsView(
                    languageStore: languageStore,
                    tabReopeningSettingsStore: tabReopeningSettingsStore,
                    notificationSettingsStore: notificationSettingsStore
                )
            }
            .tabItem { Label("General", systemImage: "gearshape") }

            SettingsTabPage {
                AppearanceSettingsView(
                    appAppearanceStore: appAppearanceStore,
                    appThemeStore: appThemeStore,
                    terminalAppearanceStore: terminalAppearanceStore
                )
            }
            .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }

            SettingsTabPage {
                PermissionsSettingsView()
            }
            .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .background(ThemePalette.contentSurface)
    }
}
