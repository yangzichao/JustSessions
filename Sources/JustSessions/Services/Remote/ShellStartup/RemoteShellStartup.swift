import Foundation

enum RemoteShellStartup: String, Codable, Sendable {
    /// `$SHELL -lic`: a login shell that also runs the interactive startup files, such as `.bashrc`, where many hosts
    /// set up PATH, for example for nvm.
    case interactive
    case loginOnly

    static let environmentVariable = "JUSTSESSIONS"

    func command(running innerCommand: String, environment: [String] = []) -> String {
        let assignments = (["\(Self.environmentVariable)=1"] + environment).joined(separator: " ")
        return "exec /usr/bin/env \(assignments) \"$SHELL\" \(shellFlags) \(ShellQuoting.quoted(innerCommand))"
    }

    var shellFlags: String {
        self == .interactive ? "-lic" : "-lc"
    }
}

final class RemoteHostShellStartups: @unchecked Sendable {
    static let shared = RemoteHostShellStartups()

    private let lock = NSLock()
    private var loginOnlyHosts: Set<String> = []
    private var hostsBeingChecked: Set<String> = []

    func beginCheck(on host: String) -> Bool {
        lock.withLock { hostsBeingChecked.insert(host).inserted }
    }

    func endCheck(on host: String) {
        _ = lock.withLock { hostsBeingChecked.remove(host) }
    }

    func startup(on host: String) -> RemoteShellStartup {
        lock.withLock { loginOnlyHosts.contains(host) } ? .loginOnly : .interactive
    }

    func setStartup(_ startup: RemoteShellStartup, on host: String) {
        lock.withLock {
            if startup == .loginOnly { loginOnlyHosts.insert(host) } else { loginOnlyHosts.remove(host) }
        }
    }
}
