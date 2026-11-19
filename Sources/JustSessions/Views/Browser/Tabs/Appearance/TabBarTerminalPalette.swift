import SwiftUI

extension EnvironmentValues {
    @Entry var tabBarTerminalPalette = AppThemeColors.justSessionsLight.terminalPalette
}

extension View {
    func tabBarTerminalPalette(from appearanceStore: TerminalAppearanceStore, themeStore: AppThemeStore) -> some View {
        modifier(TabBarTerminalPalette(appearanceStore: appearanceStore, themeStore: themeStore))
    }
}

extension TerminalPalette {
    var backgroundColor: Color {
        Color(nsColor: NSColor(hexValue: background))
    }

    var colorScheme: ColorScheme {
        isDark ? .dark : .light
    }
}

private struct TabBarTerminalPalette: ViewModifier {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    @ObservedObject var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let preferences = appearanceStore.terminalPreferences.validated
        let usesDarkColors = preferences.mode.usesDarkColors(whenAppIsDark: colorScheme == .dark)
        content.environment(
            \.tabBarTerminalPalette,
            preferences.colorVariants(appTheme: themeStore.terminalTheme).palette(usesDarkColors: usesDarkColors)
        )
    }
}
