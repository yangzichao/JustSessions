import Foundation

struct RemoteHostsUsingTmuxPrefix: Equatable {
    static let userDefaultsKey = "remoteHostsUsingTmuxPrefix"

    private(set) var hosts: Set<String>

    init(hosts: Set<String> = []) {
        self.hosts = hosts
    }

    static func load(from userDefaults: UserDefaults) -> RemoteHostsUsingTmuxPrefix {
        RemoteHostsUsingTmuxPrefix(hosts: Set(userDefaults.stringArray(forKey: userDefaultsKey) ?? []))
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(hosts.sorted(), forKey: Self.userDefaultsKey)
    }

    func usesTmuxPrefix(_ host: String) -> Bool {
        hosts.contains(host)
    }

    mutating func setUsesTmuxPrefix(_ usesTmuxPrefix: Bool, for host: String) {
        if usesTmuxPrefix {
            hosts.insert(host)
        } else {
            hosts.remove(host)
        }
    }
}
