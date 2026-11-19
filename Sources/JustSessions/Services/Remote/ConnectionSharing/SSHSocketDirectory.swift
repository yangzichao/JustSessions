import Darwin
import Foundation

/// Private folders for app-owned SSH control sockets. `/tmp` is open to every user, so the root is used only when
/// it is a real folder of this user that no one else can enter; anyone who connects to a socket uses that connection.
enum SSHSocketDirectory {
    static func makeRefreshDirectory(at rootPath: String, identifier: UUID = UUID()) -> URL? {
        makeDirectory(at: rootPath, named: "refresh-\(identifier.uuidString)")
    }

    static func makeLoginDirectory(
        at rootPath: String,
        processID: pid_t = getpid(),
        identifier: UUID = UUID()
    ) -> URL? {
        makeDirectory(at: rootPath, named: "\(loginPrefix)-\(processID)-\(identifier.uuidString)")
    }

    static func makePortForwardDirectory(
        at rootPath: String,
        processID: pid_t = getpid(),
        identifier: UUID = UUID()
    ) -> URL? {
        makeDirectory(at: rootPath, named: "\(portForwardPrefix)-\(processID)-\(identifier.uuidString)")
    }

    private static let loginPrefix = "login"
    private static let portForwardPrefix = "forward"

    static func loginDirectoriesOfEndedProcesses(
        at rootPath: String,
        isRunning: (pid_t) -> Bool = SSHSocketDirectory.isRunning
    ) -> [URL] {
        directoriesOfEndedProcesses(at: rootPath, prefix: loginPrefix, isRunning: isRunning)
    }

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
