import Combine
import Foundation

/// The saved choice of what closing a tab does when its CLI can keep running in tmux. Asks each time until you tick
/// Don't ask again in that dialog or pick an answer in Settings.
@MainActor
final class TabCloseChoiceSettingsStore: ObservableObject {
    static let shared = TabCloseChoiceSettingsStore()
    static let userDefaultsKey = "tabCloseChoice"

    @Published private(set) var choice: TabCloseChoice
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        choice = userDefaults.string(forKey: Self.userDefaultsKey).flatMap(TabCloseChoice.init(rawValue:)) ?? .askEachTime
    }

    func setChoice(_ newChoice: TabCloseChoice) {
        guard newChoice != choice else { return }
        userDefaults.set(newChoice.rawValue, forKey: Self.userDefaultsKey)
        choice = newChoice
    }
}
