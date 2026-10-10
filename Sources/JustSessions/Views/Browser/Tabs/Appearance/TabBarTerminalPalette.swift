import SwiftUI

extension EnvironmentValues {
    /// The colors terminals are drawn in. The selected tab takes their background, so it joins the terminal under it.
    @Entry var tabBarTerminalPalette = AppThemeColors.justSessionsLight.terminalPalette
}

extension View {
    /// Gives the tab bar the terminals' current colors, which follow Settings and the window's light or dark look.
    func tabBarTerminalPalette(from appearanceStore: TerminalAppearanceStore, themeStore: AppThemeStore) -> some View {
        modifier(TabBarTerminalPalette(appearanceStore: appearanceStore, themeStore: themeStore))
    }
}

extension TerminalPalette {
    /// The terminals' background, which the selected tab, a shown split's tabs, and the split area around its panes take.
    var backgroundColor: Color {
        Color(nsColor: NSColor(hexValue: background))
    }

    /// The look of what sits on the terminals' background, which can be dark in a light window or the reverse.
    var colorScheme: ColorScheme {
        isDark ? .dark : .light
    }
}

/// Picks the palette as `TerminalAppearanceStyling` does for each terminal, from the theme as terminals take it.
private struct TabBarTerminalPalette: ViewModifier {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    @ObservedObject var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let preferences = appearanceStore.preferences.validated
        let usesDarkColors = preferences.mode.usesDarkColors(whenAppIsDark: colorScheme == .dark)
        content.environment(
            \.tabBarTerminalPalette,
            preferences.colorVariants(appTheme: themeStore.terminalTheme).palette(usesDarkColors: usesDarkColors)
        )
    }
}
