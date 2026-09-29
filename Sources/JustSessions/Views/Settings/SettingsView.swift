import SwiftUI

/// The Settings window (⌘,): how the whole app looks, then how its terminals look.
struct SettingsView: View {
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore

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
        }
    }
}
