/// A theme as the app draws it: the theme's light and dark colors with your changes to them, worked out once.
struct ResolvedAppTheme: Sendable {
    let theme: AppTheme
    let customization: AppThemeCustomization
    private let lightColors: AppThemeColors
    private let darkColors: AppThemeColors

    init(_ theme: AppTheme, customization: AppThemeCustomization = AppThemeCustomization()) {
        self.theme = theme
        self.customization = customization
        lightColors = theme.colors(isDark: false).applying(customization.lightChanges)
        darkColors = theme.colors(isDark: true).applying(customization.darkChanges)
    }

    func colors(isDark: Bool) -> AppThemeColors {
        isDark ? darkColors : lightColors
    }
}

extension ResolvedAppTheme: Equatable {
    /// The colors follow from the theme and its customization, so comparing those is enough, and cheaper.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.theme == rhs.theme && lhs.customization == rhs.customization
    }
}
