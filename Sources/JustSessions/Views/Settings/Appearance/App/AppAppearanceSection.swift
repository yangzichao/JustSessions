import SwiftUI

/// The app part of the Appearance tab: System, Light, or Dark for the whole app, and the theme it is drawn in, each
/// shown as a sketch of the window, with your changes to the theme's colors under it. Rows of the tab's grid.
struct AppAppearanceSection: View {
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    /// Choosing a theme gives terminals its colors too.
    let terminalAppearanceStore: TerminalAppearanceStore

    var body: some View {
        GridRow {
            SettingsSectionHeading("App")
        }
        GridRow(alignment: .top) {
            Text("Appearance").levelWithThumbnails()
            AppAppearanceModePicker(appAppearanceStore: appAppearanceStore)
        }
        GridRow(alignment: .top) {
            Text("Theme").levelWithThumbnails()
            VStack(alignment: .leading, spacing: 14) {
                AppThemePicker(appThemeStore: appThemeStore, terminalAppearanceStore: terminalAppearanceStore)
                AppThemeColorsEditor(appThemeStore: appThemeStore)
            }
        }
    }
}
