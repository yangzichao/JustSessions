import SwiftUI

/// The Appearance tab of Settings: how the whole app looks, then how its terminals look, so the terminal colors that
/// match the app theme sit right below that theme.
struct AppearanceSettingsView: View {
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore

    var body: some View {
        // One grid, so the terminal's labels line up with the app's.
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 16) {
            AppAppearanceSection(
                appAppearanceStore: appAppearanceStore,
                appThemeStore: appThemeStore,
                terminalAppearanceStore: terminalAppearanceStore
            )
            GridRow {
                ThemeDivider().gridCellColumns(2)
            }
            TerminalAppearanceSection(appearanceStore: terminalAppearanceStore, themeStore: appThemeStore)
        }
    }
}
