import Foundation

struct TerminalAppearancePreferences: Codable, Equatable {
    static let userDefaultsKey = "terminalAppearance"
    static let fontSizeRange = 10.0...24.0
    static let defaultFontSize = 13.0

    var mode: TerminalAppearanceMode = .system
    var fontFamily: TerminalFontFamily = .system
    var fontSize: Double = defaultFontSize

    var validated: Self {
        var preferences = self
        preferences.fontSize = fontSize.isFinite
            ? min(max(fontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
            : Self.defaultFontSize
        return preferences
    }

    static func load(from userDefaults: UserDefaults) -> Self {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let preferences = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return preferences.validated
    }

    func save(to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(validated) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }
}
