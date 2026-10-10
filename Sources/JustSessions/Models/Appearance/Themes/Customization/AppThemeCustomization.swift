/// Your changes to one theme's colors, in its light and its dark version. A color you have not changed keeps the
/// theme's own.
struct AppThemeCustomization: Equatable, Sendable {
    var lightChanges: [CustomizableThemeColor: UInt32] = [:]
    var darkChanges: [CustomizableThemeColor: UInt32] = [:]

    var isEmpty: Bool { lightChanges.isEmpty && darkChanges.isEmpty }

    func changes(isDark: Bool) -> [CustomizableThemeColor: UInt32] {
        isDark ? darkChanges : lightChanges
    }

    /// Sets a color of the light or dark version, or gives it back the theme's own when the value is nil.
    mutating func setChange(_ value: UInt32?, for color: CustomizableThemeColor, isDark: Bool) {
        if isDark { darkChanges[color] = value } else { lightChanges[color] = value }
    }
}
