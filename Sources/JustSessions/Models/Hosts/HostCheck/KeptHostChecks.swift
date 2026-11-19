import Foundation

struct KeptHostCheck: Codable, Equatable, Sendable {
    let report: HostCheckReport
    let appVersion: String
}

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
