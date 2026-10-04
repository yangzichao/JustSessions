import SwiftUI

extension EnvironmentValues {
    /// The colors terminals are drawn in. The selected tab takes their background, so it joins the terminal under it.
    @Entry var tabBarTerminalPalette = AppThemeColors.justSessionsLight.terminalPalette
}

extension View {
    /// Gives the tab bar the terminals' current colors, which follow Settings and the window's light or dark look.
    func tabBarTerminalPalette(from appearanceStore: TerminalAppearanceStore) -> some View {
        modifier(TabBarTerminalPalette(appearanceStore: appearanceStore))
    }
}

/// Picks the palette as `TerminalAppearanceStyling` does for each terminal.
private struct TabBarTerminalPalette: ViewModifier {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let preferences = appearanceStore.preferences.validated
        let usesDarkColors = preferences.mode.usesDarkColors(whenAppIsDark: colorScheme == .dark)
        content.environment(
            \.tabBarTerminalPalette,
            preferences.colorVariants(appTheme: appTheme).palette(usesDarkColors: usesDarkColors)
        )
    }
}
