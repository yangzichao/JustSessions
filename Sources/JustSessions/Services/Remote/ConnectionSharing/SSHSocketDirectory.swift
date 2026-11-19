import Darwin
import Foundation

/// Private folders for app-owned SSH control sockets. `/tmp` is open to every user, so the root is used only when
/// it is a real folder of this user that no one else can enter; anyone who connects to a socket uses that connection.
enum SSHSocketDirectory {
    /// Makes a new directory for one refresh. A unique path keeps a stale socket left by a crashed app, or another
    /// refresh of the same host, from ever being mistaken for this refresh's master.
    static func makeRefreshDirectory(at rootPath: String, identifier: UUID = UUID()) -> URL? {
        makeDirectory(at: rootPath, named: "refresh-\(identifier.uuidString)")
    }

    /// Makes a new directory for one login made with Connect…, unique for the same reason as a refresh's. Its name
    /// carries the app's process ID, so a later launch can tell a login left by an app that crashed.
    static func makeLoginDirectory(
        at rootPath: String,
        processID: pid_t = getpid(),
        identifier: UUID = UUID()
    ) -> URL? {
        makeDirectory(at: rootPath, named: "\(loginPrefix)-\(processID)-\(identifier.uuidString)")
    }

    /// Makes a new directory for the connection that carries one host's port forwards, named as a login's is, for the
    /// same reason; see `SSHPortForwardConnection`.
    static func makePortForwardDirectory(
        at rootPath: String,
        processID: pid_t = getpid(),
        identifier: UUID = UUID()
    ) -> URL? {
        makeDirectory(at: rootPath, named: "\(portForwardPrefix)-\(processID)-\(identifier.uuidString)")
    }

    private static let loginPrefix = "login"
    private static let portForwardPrefix = "forward"

    /// The login directories whose app is no longer running, as after a crash; another copy of the app that still
    /// runs keeps its own. Only names made by `makeLoginDirectory` count, so a folder named any other way, whose
    /// first part may happen to be digits, is never taken for a login of an ended app.
    static func loginDirectoriesOfEndedProcesses(
        at rootPath: String,
        isRunning: (pid_t) -> Bool = SSHSocketDirectory.isRunning
    ) -> [URL] {
        directoriesOfEndedProcesses(at: rootPath, prefix: loginPrefix, isRunning: isRunning)
    }

    /// The port forward connections' directories whose app is no longer running, told apart as logins' are.
    static func portForwardDirectoriesOfEndedProcesses(
        at rootPath: String,
        isRunning: (pid_t) -> Bool = SSHSocketDirectory.isRunning
    ) -> [URL] {
        directoriesOfEndedProcesses(at: rootPath, prefix: portForwardPrefix, isRunning: isRunning)
    }

    private static func directoriesOfEndedProcesses(
        at rootPath: String,
        prefix: String,
        isRunning: (pid_t) -> Bool
    ) -> [URL] {
        guard preparedRoot(at: rootPath) != nil,
            let names = try? FileManager.default.contentsOfDirectory(atPath: rootPath)
        else { return [] }
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        return names.sorted().compactMap { name in
            let parts = name.split(separator: "-", maxSplits: 2)
            guard parts.count == 3, parts[0] == prefix, let processID = pid_t(parts[1]),
                UUID(uuidString: String(parts[2])) != nil, !isRunning(processID)
            else { return nil }
            return root.appendingPathComponent(name, isDirectory: true)
        }
    }

    static func isRunning(_ processID: pid_t) -> Bool {
        kill(processID, 0) == 0 || errno == EPERM
    }

    private static func makeDirectory(at rootPath: String, named name: String) -> URL? {
        guard preparedRoot(at: rootPath) != nil else { return nil }
        let directory = URL(fileURLWithPath: rootPath, isDirectory: true).appendingPathComponent(name, isDirectory: true)
        guard mkdir(directory.path, 0o700) == 0 else { return nil }
        return directory
    }

    /// The root, created when missing, or nil when it isn't safe to use.
    static func preparedRoot(at path: String) -> String? {
        if mkdir(path, 0o700) != 0, errno != EEXIST { return nil }
        var status = stat()
        guard lstat(path, &status) == 0,
            status.st_mode & S_IFMT == S_IFDIR,
            status.st_uid == getuid(),
            status.st_mode & 0o077 == 0
        else { return nil }
        return path
    }
}
