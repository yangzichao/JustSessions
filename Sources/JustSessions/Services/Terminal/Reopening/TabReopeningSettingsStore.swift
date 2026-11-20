import Combine
import Foundation

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

    static func isTurnedOffByLaunchArgument(in userDefaults: UserDefaults) -> Bool {
        userDefaults.volatileDomain(forName: UserDefaults.argumentDomain)[userDefaultsKey] as? Bool == false
    }

    func setReopensTabsAtLaunch(_ isOn: Bool) {
        guard isOn != reopensTabsAtLaunch else { return }
        userDefaults.set(isOn, forKey: Self.userDefaultsKey)
        reopensTabsAtLaunch = isOn
    }
}
