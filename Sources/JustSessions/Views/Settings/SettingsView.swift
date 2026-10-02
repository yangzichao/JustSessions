import SwiftUI

/// The Settings window (⌘,): what happens at launch, how the whole app looks, how its terminals look, and when it
/// notifies you.
struct SettingsView: View {
    let languageStore: AppLanguageStore
    let tabReopeningSettingsStore: TabReopeningSettingsStore
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore
    let notificationSettingsStore: SessionNotificationSettingsStore

    var body: some View {
        TabView {
            GeneralSettingsView(languageStore: languageStore, tabReopeningSettingsStore: tabReopeningSettingsStore)
                .background(ThemePalette.contentSurface)
                .tabItem { Label("General", systemImage: "gearshape") }

            AppAppearanceSettingsView(
                appAppearanceStore: appAppearanceStore,
                appThemeStore: appThemeStore,
                terminalAppearanceStore: terminalAppearanceStore
            )
            .background(ThemePalette.contentSurface)
            .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }

            TerminalAppearanceSettingsView(appearanceStore: terminalAppearanceStore, themeStore: appThemeStore)
                .background(ThemePalette.contentSurface)
                .tabItem { Label("Terminal", systemImage: "terminal") }

            NotificationSettingsView(settingsStore: notificationSettingsStore)
                .background(ThemePalette.contentSurface)
                .tabItem { Label("Notifications", systemImage: "bell.badge") }
        }
        .background(ThemePalette.contentSurface)
    }
}
