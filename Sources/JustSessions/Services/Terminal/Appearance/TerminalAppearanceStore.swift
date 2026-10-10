import Combine
import Foundation

@MainActor
final class TerminalAppearanceStore: ObservableObject {
    static let shared = TerminalAppearanceStore()

    @Published private(set) var preferences: TerminalAppearancePreferences
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        preferences = TerminalAppearancePreferences.load(from: userDefaults)
    }

    func setColorChoice(_ colorChoice: TerminalColorChoice) {
        var updated = preferences
        updated.colorChoice = colorChoice
        update(updated)
    }

    /// Saves colors read from iTerm2 or an .itermcolors file, replacing any imported before, and switches to them.
    func useImportedColors(_ importedColors: ImportedTerminalColors) {
        var updated = preferences
        updated.importedColors = importedColors
        updated.colorChoice = .imported
        update(updated)
    }

    func setMode(_ mode: TerminalAppearanceMode) {
        var updated = preferences
        updated.mode = mode
        update(updated)
    }

    func setFontFamily(_ fontFamily: TerminalFontFamily) {
        var updated = preferences
        updated.fontFamily = fontFamily
        update(updated)
    }

    func setFontSize(_ fontSize: Double) {
        var updated = preferences
        updated.fontSize = fontSize
        update(updated)
    }

    /// View → Zoom In, Zoom Out, and Actual Size while a tab shows. Every terminal shares the size, as in Settings.
    func zoomFont(_ step: TextZoomStep) {
        setFontSize(step.size(
            after: preferences.fontSize,
            in: TerminalAppearancePreferences.fontSizeRange,
            defaultSize: TerminalAppearancePreferences.defaultFontSize
        ))
    }

    func restoreDefaults() {
        update(TerminalAppearancePreferences())
    }

    private func update(_ updated: TerminalAppearancePreferences) {
        let validated = updated.validated
        guard validated != preferences else { return }
        validated.save(to: userDefaults)
        preferences = validated
    }
}
