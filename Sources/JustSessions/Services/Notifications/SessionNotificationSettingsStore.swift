import Combine
import Foundation

/// The saved choice of which moments post a macOS notification.
@MainActor
final class SessionNotificationSettingsStore: ObservableObject {
    static let shared = SessionNotificationSettingsStore()

    @Published private(set) var preferences: SessionNotificationPreferences
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        preferences = SessionNotificationPreferences.load(from: userDefaults)
    }

    func setNotifiesWhenInputNeeded(_ isOn: Bool) {
        var updated = preferences
        updated.notifiesWhenInputNeeded = isOn
        update(updated)
    }

    func setNotifiesWhenTurnFinishes(_ isOn: Bool) {
        var updated = preferences
        updated.notifiesWhenTurnFinishes = isOn
        update(updated)
    }

    private func update(_ updated: SessionNotificationPreferences) {
        guard updated != preferences else { return }
        updated.save(to: userDefaults)
        preferences = updated
    }
}
