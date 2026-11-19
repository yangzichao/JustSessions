import Foundation

struct DisconnectedRemoteHosts: Equatable {
    static let userDefaultsKey = "disconnectedRemoteHosts"

    private(set) var hosts: Set<String>

    init(hosts: Set<String> = []) {
        self.hosts = hosts
    }

    static func load(from userDefaults: UserDefaults) -> DisconnectedRemoteHosts {
        DisconnectedRemoteHosts(hosts: Set(userDefaults.stringArray(forKey: userDefaultsKey) ?? []))
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(hosts.sorted(), forKey: Self.userDefaultsKey)
    }

    func isDisconnected(_ host: String) -> Bool {
        hosts.contains(host)
    }

    mutating func setDisconnected(_ isDisconnected: Bool, for host: String) {
        if isDisconnected {
            hosts.insert(host)
        } else {
            hosts.remove(host)
        }
    }
}
