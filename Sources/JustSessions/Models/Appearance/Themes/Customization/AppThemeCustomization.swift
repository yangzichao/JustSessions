struct AppThemeCustomization: Equatable, Sendable {
    var lightChanges: [CustomizableThemeColor: UInt32] = [:]
    var darkChanges: [CustomizableThemeColor: UInt32] = [:]

    var isEmpty: Bool { lightChanges.isEmpty && darkChanges.isEmpty }

    func changes(isDark: Bool) -> [CustomizableThemeColor: UInt32] {
        isDark ? darkChanges : lightChanges
    }

    mutating func setChange(_ value: UInt32?, for color: CustomizableThemeColor, isDark: Bool) {
        if isDark { darkChanges[color] = value } else { lightChanges[color] = value }
    }
}
