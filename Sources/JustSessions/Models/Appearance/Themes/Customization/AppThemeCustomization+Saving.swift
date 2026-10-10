import Foundation

/// Every theme's customization, saved together under one key, such as
/// `{"catppuccin": {"dark": {"contentSurface": 1973806}}}`.
extension AppThemeCustomization {
    static let userDefaultsKey = "appThemeCustomizations"

    /// Theme, then "light" or "dark", then color, then its 0xRRGGBB value.
    private typealias SavedCustomizations = [String: [String: [String: UInt32]]]

    /// The saved customizations. A theme or color this version does not know is left out, and so are a version's
    /// changes once they no longer suit it.
    static func loadAll(from userDefaults: UserDefaults) -> [AppTheme: AppThemeCustomization] {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let saved = try? JSONDecoder().decode(SavedCustomizations.self, from: data) else { return [:] }
        var customizations: [AppTheme: AppThemeCustomization] = [:]
        for (themeName, savedVersions) in saved {
            guard let theme = AppTheme(rawValue: themeName) else { continue }
            var customization = AppThemeCustomization()
            for isDark in [false, true] {
                let savedChanges = savedVersions[versionKey(isDark: isDark)] ?? [:]
                let changes = Dictionary(uniqueKeysWithValues: savedChanges.compactMap { colorName, value in
                    CustomizableThemeColor(rawValue: colorName).map { ($0, value & 0xFFFFFF) }
                })
                guard theme.colors(isDark: isDark).applying(changes).suits(isDark: isDark) else { continue }
                for (color, value) in changes { customization.setChange(value, for: color, isDark: isDark) }
            }
            if !customization.isEmpty { customizations[theme] = customization }
        }
        return customizations
    }

    static func saveAll(_ customizations: [AppTheme: AppThemeCustomization], to userDefaults: UserDefaults) {
        let saved: SavedCustomizations = Dictionary(uniqueKeysWithValues: customizations.map { theme, customization in
            let versions = [false, true].reduce(into: [String: [String: UInt32]]()) { versions, isDark in
                let changes = customization.changes(isDark: isDark)
                guard !changes.isEmpty else { return }
                versions[versionKey(isDark: isDark)] = Dictionary(uniqueKeysWithValues: changes.map { ($0.rawValue, $1) })
            }
            return (theme.rawValue, versions)
        })
        guard let data = try? JSONEncoder().encode(saved) else { return }
        userDefaults.set(data, forKey: userDefaultsKey)
    }

    private static func versionKey(isDark: Bool) -> String {
        isDark ? "dark" : "light"
    }
}
