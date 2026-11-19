import Combine
import Foundation

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
