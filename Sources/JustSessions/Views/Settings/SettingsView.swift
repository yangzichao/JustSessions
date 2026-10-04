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
            GeneralSettingsView(
                languageStore: languageStore,
                tabReopeningSettingsStore: tabReopeningSettingsStore,
                notificationSettingsStore: notificationSettingsStore
            )
            .background(ThemePalette.contentSurface)
            .tabItem { Label("General", systemImage: "gearshape") }

            AppearanceSettingsView(
                appAppearanceStore: appAppearanceStore,
                appThemeStore: appThemeStore,
                terminalAppearanceStore: terminalAppearanceStore
            )
            .background(ThemePalette.contentSurface)
            .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }

            PermissionsSettingsView()
                .background(ThemePalette.contentSurface)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .background(ThemePalette.contentSurface)
    }
}
