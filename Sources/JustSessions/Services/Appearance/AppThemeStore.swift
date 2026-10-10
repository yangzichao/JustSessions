import Combine
import Foundation

/// The theme chosen in Settings, and your changes to each theme's colors. Each window puts the chosen theme in its
/// views' environment, and terminals restyle from it.
@MainActor
final class AppThemeStore: ObservableObject {
    static let shared = AppThemeStore()

    /// The chosen theme with your changes to its colors.
    @Published private(set) var resolvedTheme: ResolvedAppTheme
    /// Kept for every theme, so choosing another theme and coming back brings your changes back.
    private var customizations: [AppTheme: AppThemeCustomization]
    private let userDefaults: UserDefaults

    var theme: AppTheme { resolvedTheme.theme }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let customizations = AppThemeCustomization.loadAll(from: userDefaults)
        let theme = AppTheme.load(from: userDefaults)
        self.customizations = customizations
        resolvedTheme = ResolvedAppTheme(theme, customization: customizations[theme] ?? AppThemeCustomization())
    }

    func setTheme(_ newTheme: AppTheme) {
        guard newTheme != theme else { return }
        newTheme.save(to: userDefaults)
        resolvedTheme = resolvedTheme(for: newTheme)
    }

    /// Any theme with your changes, as the theme picker draws it.
    func resolvedTheme(for theme: AppTheme) -> ResolvedAppTheme {
        theme == self.theme
            ? resolvedTheme
            : ResolvedAppTheme(theme, customization: customizations[theme] ?? AppThemeCustomization())
    }

    /// Changes one color of the chosen theme's light or dark version; nil, or the theme's own color, gives it back the
    /// theme's own. Returns false, changing nothing, when the version would no longer suit its appearance: a surface
    /// of the wrong lightness, or one text can't be made readable on.
    @discardableResult
    func setColor(_ value: UInt32?, for color: CustomizableThemeColor, isDark: Bool) -> Bool {
        let themeColors = theme.colors(isDark: isDark)
        var customization = resolvedTheme.customization
        customization.setChange(value == color.value(in: themeColors.seeds) ? nil : value, for: color, isDark: isDark)
        guard themeColors.applying(customization.changes(isDark: isDark)).suits(isDark: isDark) else { return false }
        update(customization)
        return true
    }

    /// Gives the chosen theme back all its own colors.
    func removeCustomization() {
        update(AppThemeCustomization())
    }

    private func update(_ customization: AppThemeCustomization) {
        guard customization != resolvedTheme.customization else { return }
        customizations[theme] = customization.isEmpty ? nil : customization
        AppThemeCustomization.saveAll(customizations, to: userDefaults)
        resolvedTheme = ResolvedAppTheme(theme, customization: customization)
    }
}
