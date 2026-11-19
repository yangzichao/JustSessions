struct ResolvedAppTheme: Sendable {
    let theme: AppTheme
    let customization: AppThemeCustomization
    private let lightColors: AppThemeColors
    private let darkColors: AppThemeColors

    init(_ theme: AppTheme, customization: AppThemeCustomization = AppThemeCustomization()) {
        self.init(
            theme: theme, customization: customization,
            lightColors: theme.colors(isDark: false).applying(customization.lightChanges),
            darkColors: theme.colors(isDark: true).applying(customization.darkChanges)
        )
    }

    private init(theme: AppTheme, customization: AppThemeCustomization, lightColors: AppThemeColors, darkColors: AppThemeColors) {
        self.theme = theme
        self.customization = customization
        self.lightColors = lightColors
        self.darkColors = darkColors
    }

    func colors(isDark: Bool) -> AppThemeColors {
        isDark ? darkColors : lightColors
    }

    func replacingCustomization(with customization: AppThemeCustomization, changedVersionIsDark isDark: Bool) -> ResolvedAppTheme {
        let changedColors = theme.colors(isDark: isDark).applying(customization.changes(isDark: isDark))
        return ResolvedAppTheme(
            theme: theme, customization: customization,
            lightColors: isDark ? lightColors : changedColors,
            darkColors: isDark ? changedColors : darkColors
        )
    }
}

extension ResolvedAppTheme: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.theme == rhs.theme && lhs.customization == rhs.customization
    }
}
