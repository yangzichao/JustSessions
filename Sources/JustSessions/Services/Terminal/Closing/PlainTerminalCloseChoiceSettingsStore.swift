import Combine
import Foundation

/// The saved choice of what closing a plain terminal's tab does. Asks each time until you tick Don't ask again in that
/// dialog or pick an answer in Settings.
@MainActor
final class PlainTerminalCloseChoiceSettingsStore: ObservableObject {
    static let shared = PlainTerminalCloseChoiceSettingsStore()
    static let userDefaultsKey = "plainTerminalCloseChoice"

    @Published private(set) var choice: PlainTerminalCloseChoice
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        choice = userDefaults.string(forKey: Self.userDefaultsKey).flatMap(PlainTerminalCloseChoice.init(rawValue:))
            ?? .askEachTime
    }

    func setChoice(_ newChoice: PlainTerminalCloseChoice) {
        guard newChoice != choice else { return }
        userDefaults.set(newChoice.rawValue, forKey: Self.userDefaultsKey)
        choice = newChoice
    }
}
