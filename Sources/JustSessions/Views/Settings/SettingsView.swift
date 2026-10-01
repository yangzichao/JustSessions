import SwiftUI

/// The Settings window (⌘,): how the whole app looks, how its terminals look, and when it notifies you.
struct SettingsView: View {
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore
    let notificationSettingsStore: SessionNotificationSettingsStore

    var body: some View {
        TabView {
            AppAppearanceSettingsView(
                appAppearanceStore: appAppearanceStore,
                appThemeStore: appThemeStore,
                terminalAppearanceStore: terminalAppearanceStore
            )
            .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }

            TerminalAppearanceSettingsView(appearanceStore: terminalAppearanceStore, themeStore: appThemeStore)
                .tabItem { Label("Terminal", systemImage: "terminal") }

            NotificationSettingsView(settingsStore: notificationSettingsStore)
                .tabItem { Label("Notifications", systemImage: "bell.badge") }
        }
    }
}
