import Foundation

struct RemoteShellStartupCheckResult: Codable, Equatable, Sendable {
    enum Outcome: String, Codable, Sendable {
        case interactiveStartupWorks
        case usesLoginShellOnly
        case blocked
    }

    let outcome: Outcome
    let stoppedAt: String?

    var shellStartup: RemoteShellStartup { outcome == .usesLoginShellOnly ? .loginOnly : .interactive }
}

struct RemoteShellStartupChecks: Equatable {
    static let userDefaultsKey = "remoteShellStartupChecks"

    private(set) var resultsByHost: [String: RemoteShellStartupCheckResult]

    init(resultsByHost: [String: RemoteShellStartupCheckResult] = [:]) {
        self.resultsByHost = resultsByHost
    }

    static func load(from userDefaults: UserDefaults) -> RemoteShellStartupChecks {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
            let resultsByHost = try? JSONDecoder().decode([String: RemoteShellStartupCheckResult].self, from: data)
        else { return RemoteShellStartupChecks() }
        return RemoteShellStartupChecks(resultsByHost: resultsByHost)
    }

    func save(to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(resultsByHost) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    func result(for host: String) -> RemoteShellStartupCheckResult? {
        resultsByHost[host]
    }

    mutating func setResult(_ result: RemoteShellStartupCheckResult?, for host: String) {
        resultsByHost[host] = result
    }
}
