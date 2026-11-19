import Combine
import Foundation

/// The saved choice of what ⌘-clicking a link to a file on this Mac does; see `FileLinkClickChoice`. Opens it in its
/// default app until you pick something else in Settings.
@MainActor
final class FileLinkClickSettingsStore: ObservableObject {
    static let shared = FileLinkClickSettingsStore()

    @Published private(set) var choice: FileLinkClickChoice
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        choice =
            userDefaults.string(forKey: FileLinkClickChoice.userDefaultsKey).flatMap(FileLinkClickChoice.init(storedValue:))
            ?? .defaultApp
    }

    func setChoice(_ newChoice: FileLinkClickChoice) {
        guard newChoice != choice else { return }
        userDefaults.set(newChoice.storedValue, forKey: FileLinkClickChoice.userDefaultsKey)
        choice = newChoice
    }
}
