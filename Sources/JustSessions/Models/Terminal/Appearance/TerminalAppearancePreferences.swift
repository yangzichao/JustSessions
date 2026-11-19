import Foundation

struct TerminalAppearancePreferences: Codable, Equatable {
    static let userDefaultsKey = "terminalAppearance"
    static let fontSizeRange = 10.0...24.0
    static let defaultFontSize = 13.0

    var colorChoice: TerminalColorChoice = .matchAppTheme
    var importedColors: ImportedTerminalColors?
    var mode: TerminalAppearanceMode = .matchApp
    var fontFamily: TerminalFontFamily = .system
    var fontSize: Double = defaultFontSize
    var colorIntensityPercent = TerminalColorIntensity.defaultPercent

    var validated: Self {
        var preferences = self
        if colorChoice == .imported && importedColors == nil { preferences.colorChoice = .matchAppTheme }
        preferences.fontSize =
            fontSize.isFinite
            ? min(max(fontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
            : Self.defaultFontSize
        let intensityRange = TerminalColorIntensity.percentRange
        preferences.colorIntensityPercent = min(max(colorIntensityPercent, intensityRange.lowerBound), intensityRange.upperBound)
        return preferences
    }

    func colorVariants(appTheme: ResolvedAppTheme) -> TerminalPaletteVariants {
        let chosenVariants =
            switch colorChoice {
            case .matchAppTheme: TerminalPaletteVariants(appTheme: appTheme)
            case .preset(let preset): preset.variants
            case .imported: importedColors?.variants ?? TerminalPaletteVariants(appTheme: appTheme)
            }
        return chosenVariants.withANSIColorIntensity(percent: colorIntensityPercent)
    }

    static func load(from userDefaults: UserDefaults) -> Self {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
            let preferences = try? JSONDecoder().decode(Self.self, from: data)
        else { return Self() }
        return preferences.validated
    }

    func save(to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(validated) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }
}

extension TerminalAppearancePreferences {
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
        if let colorIntensityPercent = try? container.decode(Int.self, forKey: .colorIntensityPercent) {
            self.colorIntensityPercent = colorIntensityPercent
        }
    }
}
