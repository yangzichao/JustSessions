import SwiftUI

struct AppearanceSettingsView: View {
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore
    let terminalEngineStore: TerminalEngineStore
    let terminalOptionKeyStore: TerminalOptionKeyStore

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 16) {
            AppAppearanceSection(
                appAppearanceStore: appAppearanceStore,
                appThemeStore: appThemeStore,
                terminalAppearanceStore: terminalAppearanceStore
            )
            GridRow {
                ThemeDivider().gridCellColumns(2)
            }
            TerminalAppearanceSection(
                appearanceStore: terminalAppearanceStore,
                engineStore: terminalEngineStore,
                optionKeyStore: terminalOptionKeyStore,
                themeStore: appThemeStore
            )
        }
    }
}
