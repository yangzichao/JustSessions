import Foundation

/// Which moments post a macOS notification. Both are on until turned off in Settings.
struct SessionNotificationPreferences: Codable, Equatable {
    static let userDefaultsKey = "sessionNotifications"

    var notifiesWhenInputNeeded = true
    var notifiesWhenTurnFinishes = true

    func allows(_ reason: SessionAttentionReason) -> Bool {
        switch reason {
        case .needsInput: notifiesWhenInputNeeded
        case .finishedTurn: notifiesWhenTurnFinishes
        }
    }

    static func load(from userDefaults: UserDefaults) -> Self {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let preferences = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return preferences
    }

    func save(to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }
}

extension SessionNotificationPreferences {
    /// Reads each setting on its own, so a missing value, or one this version does not know, resets only that setting.
    init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let isOn = try? container.decode(Bool.self, forKey: .notifiesWhenInputNeeded) { notifiesWhenInputNeeded = isOn }
        if let isOn = try? container.decode(Bool.self, forKey: .notifiesWhenTurnFinishes) { notifiesWhenTurnFinishes = isOn }
    }
}
