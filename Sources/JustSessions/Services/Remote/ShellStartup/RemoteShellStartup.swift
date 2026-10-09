import Foundation

/// How the app starts an SSH host's login shell for the commands it runs there, so the shell finds the CLIs and
/// `tmux` wherever the host's startup files put them. Every such shell gets `JUSTSESSIONS=1`, so a startup file can
/// leave out what would get in the way, such as starting tmux or another shell.
enum RemoteShellStartup: String, Codable, Sendable {
    /// `$SHELL -lic`: a login shell that also runs the interactive startup files, such as `.bashrc`, where many hosts
    /// set up PATH, for example for nvm.
    case interactive
    /// `$SHELL -lc`, for a host whose interactive startup starts another program, such as tmux or another shell,
    /// before the app's command can run; see `RemoteShellStartupCheck`.
    case loginOnly

    static let environmentVariable = "JUSTSESSIONS"

    /// Runs `innerCommand` in the host's login shell. The outer command is read by the host's own shell, which may be
    /// fish, so it leaves the shell syntax to `innerCommand`.
    func command(running innerCommand: String) -> String {
        let flags = self == .interactive ? "-lic" : "-lc"
        return "exec /usr/bin/env \(Self.environmentVariable)=1 \"$SHELL\" \(flags) \(ShellQuoting.quoted(innerCommand))"
    }
}

/// Which SSH hosts start their login shell without the interactive startup files; see `RemoteShellStartupCheck`. The
/// store sets it from the check results it keeps, and command builders on any thread read it. It also keeps each
/// window's store from checking a host another window is checking.
final class RemoteHostShellStartups: @unchecked Sendable {
    static let shared = RemoteHostShellStartups()

    private let lock = NSLock()
    private var loginOnlyHosts: Set<String> = []
    private var hostsBeingChecked: Set<String> = []

    /// False when the host is being checked already.
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
