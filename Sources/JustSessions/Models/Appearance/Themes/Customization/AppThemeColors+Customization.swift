extension AppThemeColors {
    /// The variant with the changed colors in place of its own; itself when nothing changed, so a built-in theme does
    /// no contrast work again.
    func applying(_ changedColors: [CustomizableThemeColor: UInt32]) -> AppThemeColors {
        changedColors.isEmpty ? self : AppThemeColors(seeds: seeds.applying(changedColors))
    }

    /// Whether this variant can be drawn in the light or the dark appearance: its surfaces are all light, or all dark,
    /// so the window's own controls match them, and every text color reads at 4.5 on every surface it sits on and on
    /// the ink. The built-in themes are checked by tests; a customized one is checked before it is taken.
    func suits(isDark: Bool) -> Bool {
        let surfaces = [sidebarSurface, contentSurface, raisedSurface, userMessageSurface]
        guard surfaces.allSatisfy({ ThemeColorContrast.isDark($0) == isDark }) else { return false }
        let textColors = [ink, secondaryText, tertiaryText, warningText, errorText] + providerTextHexColors.values
        let textIsReadable = textColors.allSatisfy { textColor in
            textSurfaces.allSatisfy { ThemeColorContrast.ratio(textColor, $0) >= ThemeColorContrast.minimumTextRatio }
        }
        return textIsReadable && ThemeColorContrast.ratio(inkForeground, ink) >= ThemeColorContrast.minimumTextRatio
    }
}
