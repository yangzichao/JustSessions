import SwiftUI

/// The Settings window (⌘,): how the whole app looks, then how its terminals look.
struct SettingsView: View {
    let appAppearanceStore: AppAppearanceStore
    let terminalAppearanceStore: TerminalAppearanceStore

    var body: some View {
        TabView {
            AppAppearanceSettingsView(
                appAppearanceStore: appAppearanceStore,
                terminalAppearanceStore: terminalAppearanceStore
            )
            .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }

            TerminalAppearanceSettingsView(appearanceStore: terminalAppearanceStore)
                .tabItem { Label("Terminal", systemImage: "terminal") }
        }
    }
}
