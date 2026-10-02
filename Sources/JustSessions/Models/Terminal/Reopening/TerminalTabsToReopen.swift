import Foundation

/// The tabs saved when the app last quit, in tab bar order.
struct TerminalTabsToReopen: Codable, Equatable {
    static let userDefaultsKey = "terminalTabsToReopen"

    var tabs: [ReopenableTerminalTab] = []

    static func load(from userDefaults: UserDefaults) -> Self {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let saved = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return saved
    }

    func save(to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }
}
