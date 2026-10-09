import Foundation

/// What `RemoteShellStartupCheck` found about an SSH host's shell startup.
struct RemoteShellStartupCheckResult: Codable, Equatable, Sendable {
    enum Outcome: String, Codable, Sendable {
        /// The interactive startup lets the app's commands run.
        case interactiveStartupWorks
        /// The interactive startup starts another program first; a login shell without it runs the app's commands.
        case usesLoginShellOnly
        /// Neither runs the app's commands, so a tab opens a shell or another program instead of its CLI until the
        /// host's startup files change.
        case blocked
    }

    let outcome: Outcome
    /// The last command the interactive startup ran, as `file:line: command`, when it did not let the app's command
    /// run and the shell, bash or zsh, could trace it.
    let stoppedAt: String?

    var shellStartup: RemoteShellStartup { outcome == .usesLoginShellOnly ? .loginOnly : .interactive }
}

/// Each SSH host's last shell startup check, kept so a host is checked again only when something suggests its
/// startup changed; see `ConversationStore+RemoteShellStartup`.
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
