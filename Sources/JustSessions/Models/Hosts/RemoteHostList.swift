import Foundation

struct RemoteHostList: Equatable {
    static let userDefaultsKey = "remoteHosts"

    private(set) var hosts: [String]

    init(hosts: [String] = []) {
        self.hosts = hosts
    }

    static func load(from userDefaults: UserDefaults) -> RemoteHostList {
        RemoteHostList(hosts: userDefaults.stringArray(forKey: userDefaultsKey) ?? [])
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(hosts, forKey: Self.userDefaultsKey)
    }

    static func normalizedHost(_ proposedHost: String) -> String? {
        let host = proposedHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !host.hasPrefix("-"),
            host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
            !host.contains("/"),
            !host.allSatisfy({ $0 == "." })
        else { return nil }
        return host
    }

    @discardableResult
    mutating func add(_ proposedHost: String) -> Bool {
        guard let host = Self.normalizedHost(proposedHost), !hosts.contains(host) else { return false }
        hosts.append(host)
        return true
    }

    mutating func remove(_ host: String) {
        hosts.removeAll { $0 == host }
    }
}
