import Foundation

/// An SSH host's last host check, from Check this host… or one the app ran on its own, with the version of the app
/// that ran it, since a newer version may check more.
struct KeptHostCheck: Codable, Equatable, Sendable {
    let report: HostCheckReport
    /// The app's version, as `FeedbackEnvironment.appVersion` gives it.
    let appVersion: String
}

/// Each SSH host's last host check, kept across launches, so its heading warns of a problem it found and the app
/// knows when the host is due another; see `HostBackgroundCheckSchedule`.
struct KeptHostChecks: Equatable {
    static let userDefaultsKey = "keptHostChecks"

    private(set) var checksByHost: [String: KeptHostCheck]

    init(checksByHost: [String: KeptHostCheck] = [:]) {
        self.checksByHost = checksByHost
    }

    static func load(from userDefaults: UserDefaults) -> KeptHostChecks {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
            let checksByHost = try? JSONDecoder().decode([String: KeptHostCheck].self, from: data)
        else { return KeptHostChecks() }
        return KeptHostChecks(checksByHost: checksByHost)
    }

    func save(to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(checksByHost) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    func check(for host: String) -> KeptHostCheck? {
        checksByHost[host]
    }

    mutating func setCheck(_ check: KeptHostCheck?, for host: String) {
        checksByHost[host] = check
    }
}
