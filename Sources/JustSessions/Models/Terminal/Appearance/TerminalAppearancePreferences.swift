import Foundation

struct TerminalAppearancePreferences: Codable, Equatable {
    static let userDefaultsKey = "terminalAppearance"
    static let fontSizeRange = 10.0...24.0
    static let defaultFontSize = 13.0

    var colorChoice: TerminalColorChoice = .matchAppTheme
    /// Kept after choosing another scheme, so the imported colors stay one click away.
    var importedColors: ImportedTerminalColors?
    var mode: TerminalAppearanceMode = .matchApp
    var fontFamily: TerminalFontFamily = .system
    var fontSize: Double = defaultFontSize

    var validated: Self {
        var preferences = self
        if colorChoice == .imported && importedColors == nil { preferences.colorChoice = .matchAppTheme }
        preferences.fontSize = fontSize.isFinite
            ? min(max(fontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
            : Self.defaultFontSize
        return preferences
    }

    /// The chosen colors, in one version or in light and dark.
    func colorVariants(appTheme: ResolvedAppTheme) -> TerminalPaletteVariants {
        switch colorChoice {
        case .matchAppTheme: TerminalPaletteVariants(appTheme: appTheme)
        case .preset(let preset): preset.variants
        case .imported: importedColors?.variants ?? TerminalPaletteVariants(appTheme: appTheme)
        }
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

extension TerminalAppearancePreferences {
    /// Reads each setting on its own, so a missing value, or one this version does not know, resets only that setting.
    init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let colorChoice = try? container.decode(TerminalColorChoice.self, forKey: .colorChoice) { self.colorChoice = colorChoice }
        if let importedColors = try? container.decode(ImportedTerminalColors.self, forKey: .importedColors) {
            self.importedColors = importedColors
        }
        if let mode = try? container.decode(TerminalAppearanceMode.self, forKey: .mode) { self.mode = mode }
        if let fontFamily = try? container.decode(TerminalFontFamily.self, forKey: .fontFamily) { self.fontFamily = fontFamily }
        if let fontSize = try? container.decode(Double.self, forKey: .fontSize) { self.fontSize = fontSize }
    }
}
