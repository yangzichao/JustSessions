import Combine
import Foundation

/// The saved choice of whether the app reopens the tabs of the last quit at launch. On until turned off in Settings.
@MainActor
final class TabReopeningSettingsStore: ObservableObject {
    static let shared = TabReopeningSettingsStore()
    static let userDefaultsKey = "reopensTabsAtLaunch"

    @Published private(set) var reopensTabsAtLaunch: Bool
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        reopensTabsAtLaunch = userDefaults.object(forKey: Self.userDefaultsKey) as? Bool ?? true
    }

    func setReopensTabsAtLaunch(_ isOn: Bool) {
        guard isOn != reopensTabsAtLaunch else { return }
        userDefaults.set(isOn, forKey: Self.userDefaultsKey)
        reopensTabsAtLaunch = isOn
    }
}
