import SwiftUI

/// The Appearance tab of Settings: System, Light, or Dark for the whole app, and the theme it is drawn in, each shown
/// as a sketch of the window.
struct AppAppearanceSettingsView: View {
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    @ObservedObject var terminalAppearanceStore: TerminalAppearanceStore

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 20) {
            GridRow(alignment: .top) {
                Text("Appearance").levelWithThumbnails()
                AppAppearanceModePicker(appAppearanceStore: appAppearanceStore)
            }
            GridRow(alignment: .top) {
                Text("Theme").levelWithThumbnails()
                AppThemePicker(appThemeStore: appThemeStore)
            }
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Text(terminalNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: 540, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Terminals can have colors of their own, so say whether they follow this choice.
    private var terminalNote: LocalizedStringKey {
        switch terminalAppearanceStore.preferences.mode {
        case .matchApp: "Terminals use the theme's colors and match the app unless you set Light or Dark in the Terminal tab."
        case .light: "Terminals use the theme's light colors, as set in the Terminal tab."
        case .dark: "Terminals use the theme's dark colors, as set in the Terminal tab."
        }
    }
}
