import Foundation

/// The SSH logins made with Connect…, for hosts that ask for a password, a passphrase, or a code: one app-owned master
/// connection per host. While it is open, every command, copy, and tab of the app's on that host goes through it, so
/// nothing asks again. It stays open with nothing using it, and closes when the connection drops, as when the Mac
/// sleeps, on Disconnect, when the host is removed, and when the app quits. Nothing typed to log in is kept.
final class SSHLoginConnections: @unchecked Sendable {
    static let shared = SSHLoginConnections()

    /// `ControlPersist`: a login has no idle limit. One left behind by an app that crashed is closed at the next
    /// launch; see `closeLoginsOfEndedApps(socketRoot:)`.
    static let persistence = "yes"

    private let lock = NSLock()
    private var directoriesByHost: [String: URL] = [:]
    private let close: @Sendable (_ host: String, _ controlPath: String) -> Void

    init(close: (@Sendable (_ host: String, _ controlPath: String) -> Void)? = nil) {
        self.close = close ?? Self.closeMaster
    }

    static func controlPath(in directory: URL) -> String {
        directory.appendingPathComponent("master").path
    }

    /// The control socket of the host's open login. A master that ended on its own removed its socket.
    func controlPath(for host: String) -> String? {
        guard let directory = lock.withLock({ directoriesByHost[host] }) else { return nil }
        let path = Self.controlPath(in: directory)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    func isLoggedIn(_ host: String) -> Bool {
        controlPath(for: host) != nil
    }

    var loggedInHosts: Set<String> {
        Set(lock.withLock { Array(directoriesByHost.keys) }.filter(isLoggedIn))
    }

    /// The `ssh` options that send a connection through the host's open login, or none. They come before any others,
    /// since `ssh` keeps the first value it gets for an option; `ControlMaster=no` keeps a connection from becoming a
    /// master of its own when the login has just ended, so it logs in as it would have without one.
    func connectionOptions(for host: String) -> [String] {
        guard let controlPath = controlPath(for: host) else { return [] }
        return ["-o", "ControlMaster=no", "-o", "ControlPath=\(controlPath)"]
    }

    /// Keeps the login whose master listens in `directory`, closing an earlier one of the host's.
    func add(_ directory: URL, for host: String) {
        let earlierDirectory = lock.withLock {
            defer { directoriesByHost[host] = directory }
            return directoriesByHost[host]
        }
        if let earlierDirectory, earlierDirectory != directory { closeMasterInBackground(in: earlierDirectory, host: host) }
    }

    /// Ends the host's login and the tabs going through it; their CLIs keep running in tmux. Connections made from
    /// now on no longer use it; the master itself is closed in the background.
    func disconnect(_ host: String) {
        guard let directory = lock.withLock({ directoriesByHost.removeValue(forKey: host) }) else { return }
        closeMasterInBackground(in: directory, host: host)
    }

    /// Forgets the host's login once its master has ended on its own, as when the connection dropped, and removes its
    /// folder. A login still open is kept.
    func forgetEndedLogin(of host: String) {
        let directory: URL? = lock.withLock {
            guard let directory = directoriesByHost[host],
                !FileManager.default.fileExists(atPath: Self.controlPath(in: directory))
            else { return nil }
            directoriesByHost.removeValue(forKey: host)
            return directory
        }
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    /// When the app quits: waits for every master to close.
    func disconnectAll() {
        let directories = lock.withLock {
            defer { directoriesByHost.removeAll() }
            return directoriesByHost
        }
        for (host, directory) in directories { closeMaster(in: directory, host: host) }
    }

    /// At launch: closes the logins that a copy of the app that is no longer running left open, as after a crash,
    /// since they have no idle limit to end them.
    static func closeLoginsOfEndedApps(
        socketRoot: String = SSHConnectionSharing.socketRoot,
        close: @Sendable (_ host: String, _ controlPath: String) -> Void = SSHLoginConnections.closeMaster
    ) {
        for directory in SSHSocketDirectory.loginDirectoriesOfEndedProcesses(at: socketRoot) {
            let controlPath = Self.controlPath(in: directory)
            // `ssh -O exit` needs a destination, but the socket alone picks the master.
            if FileManager.default.fileExists(atPath: controlPath) { close("left-by-ended-app", controlPath) }
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func closeMasterInBackground(in directory: URL, host: String) {
        DispatchQueue.global(qos: .utility).async { [self] in closeMaster(in: directory, host: host) }
    }

    private func closeMaster(in directory: URL, host: String) {
        let controlPath = Self.controlPath(in: directory)
        if FileManager.default.fileExists(atPath: controlPath) { close(host, controlPath) }
        try? FileManager.default.removeItem(at: directory)
    }

    static func closeMaster(host: String, controlPath: String) {
        _ = BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/ssh",
            arguments: ["-O", "exit", "-S", controlPath, "-o", "BatchMode=yes", "--", host],
            environment: SSHProcessEnvironment.standard,
            includesStandardError: true,
            timeout: 10
        )
    }
}
