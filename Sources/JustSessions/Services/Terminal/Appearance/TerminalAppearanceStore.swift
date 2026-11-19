import Combine
import Foundation

@MainActor
final class TerminalAppearanceStore: ObservableObject {
    static let shared = TerminalAppearanceStore()

    /// The settings as Settings shows them.
    @Published private(set) var preferences: TerminalAppearancePreferences
    /// The settings as terminals and the tab bar take them. They follow `preferences` at once, except while the color
    /// intensity is dragged: then they wait until dragging pauses, so terminals recolor, and tell the CLIs that
    /// subscribe to color changes, once rather than at every step.
    @Published private(set) var terminalPreferences: TerminalAppearancePreferences
    private let userDefaults: UserDefaults
    private let terminalPreferencesDelay: Duration
    private var pendingTerminalPreferences: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard, terminalPreferencesDelay: Duration = .milliseconds(250)) {
        self.userDefaults = userDefaults
        self.terminalPreferencesDelay = terminalPreferencesDelay
        let preferences = TerminalAppearancePreferences.load(from: userDefaults)
        self.preferences = preferences
        terminalPreferences = preferences
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

    func setColorIntensityPercent(_ percent: Int) {
        var updated = preferences
        updated.colorIntensityPercent = percent
        update(updated, terminalsWait: true)
    }

    /// View → Zoom In, Zoom Out, and Actual Size while a tab shows. Every terminal shares the size, as in Settings.
    func zoomFont(_ step: TextZoomStep) {
        setFontSize(
            step.size(
                after: preferences.fontSize,
                in: TerminalAppearancePreferences.fontSizeRange,
                defaultSize: TerminalAppearancePreferences.defaultFontSize
            ))
    }

    func restoreDefaults() {
        update(TerminalAppearancePreferences())
    }

    private func update(_ updated: TerminalAppearancePreferences, terminalsWait: Bool = false) {
        let validated = updated.validated
        guard validated != preferences else { return }
        validated.save(to: userDefaults)
        preferences = validated
        pendingTerminalPreferences?.cancel()
        guard terminalsWait else {
            terminalPreferences = validated
            return
        }
        pendingTerminalPreferences = Task { [weak self, terminalPreferencesDelay] in
            try? await Task.sleep(for: terminalPreferencesDelay)
            guard !Task.isCancelled, let self else { return }
            terminalPreferences = preferences
        }
    }
}
