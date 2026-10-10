import Foundation

/// Every theme's customization, saved together under one key, such as
/// `{"catppuccin": {"dark": {"contentSurface": 1973806}}}`.
extension AppThemeCustomization {
    static let userDefaultsKey = "appThemeCustomizations"

    /// The saved customizations. Each color is read on its own, so a theme, color, or value this version does not
    /// know leaves out only itself, and a version's changes are left out once its surfaces no longer suit it.
    static func loadAll(from userDefaults: UserDefaults) -> [AppTheme: AppThemeCustomization] {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var customizations: [AppTheme: AppThemeCustomization] = [:]
        for (themeName, savedVersions) in saved {
            guard let theme = AppTheme(rawValue: themeName), let savedVersions = savedVersions as? [String: Any] else {
                continue
            }
            var customization = AppThemeCustomization()
            for isDark in [false, true] {
                let changes = changes(from: savedVersions[versionKey(isDark: isDark)])
                guard theme.colors(isDark: isDark).seeds.applying(changes).surfacesSuit(isDark: isDark) else { continue }
                for (color, value) in changes { customization.setChange(value, for: color, isDark: isDark) }
            }
            if !customization.isEmpty { customizations[theme] = customization }
        }
        return customizations
    }

    static func saveAll(_ customizations: [AppTheme: AppThemeCustomization], to userDefaults: UserDefaults) {
        let saved = Dictionary(uniqueKeysWithValues: customizations.map { theme, customization in
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

    private static func changes(from savedVersion: Any?) -> [CustomizableThemeColor: UInt32] {
        guard let savedVersion = savedVersion as? [String: Any] else { return [:] }
        return savedVersion.reduce(into: [:]) { changes, entry in
            guard let color = CustomizableThemeColor(rawValue: entry.key),
                  let number = entry.value as? NSNumber,
                  let value = UInt32(exactly: number.doubleValue), value <= 0xFFFFFF else { return }
            changes[color] = value
        }
    }

    private static func versionKey(isDark: Bool) -> String {
        isDark ? "dark" : "light"
    }
}
