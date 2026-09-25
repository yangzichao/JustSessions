import Foundation

/// SSH hosts whose sessions JustSessions lists after this Mac's. Each entry is what you would type after `ssh`:
/// a `Host` alias from `~/.ssh/config`, or `user@hostname`.
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

    /// The host as it will be stored, or nil when it cannot be passed to `ssh` safely.
    static func normalizedHost(_ proposedHost: String) -> String? {
        let host = proposedHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !host.hasPrefix("-"),
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !host.contains("/") else { return nil }
        return host
    }

    /// Adds the host unless it is invalid or already listed; returns whether the list changed.
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
