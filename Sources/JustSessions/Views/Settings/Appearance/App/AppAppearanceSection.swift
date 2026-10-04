import SwiftUI

/// The app part of the Appearance tab: System, Light, or Dark for the whole app, and the theme it is drawn in, each
/// shown as a sketch of the window. Rows of the tab's grid.
struct AppAppearanceSection: View {
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore

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
            AppThemePicker(appThemeStore: appThemeStore)
        }
    }
}
