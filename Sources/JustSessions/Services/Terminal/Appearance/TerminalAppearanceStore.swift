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
