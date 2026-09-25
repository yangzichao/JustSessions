import Foundation

/// A project folder on a host. Its `key` is what grouping, pinning, and custom project names use: the folder's path
/// on this Mac, and `ssh://<host><absolute path>` on an SSH host, so folders at the same path on two hosts never merge.
struct ProjectLocation: Hashable, Sendable {
    private static let sshKeyScheme = "ssh://"

    let host: SessionHost
    let path: String

    init(host: SessionHost, path: String) {
        self.host = host
        self.path = path
    }

    /// Reads a project key back. Anything that is not an SSH key is a folder on this Mac.
    init(key: String) {
        if key.hasPrefix(Self.sshKeyScheme) {
            let hostAndPath = key.dropFirst(Self.sshKeyScheme.count)
            if let pathStart = hostAndPath.firstIndex(of: "/"), pathStart != hostAndPath.startIndex {
                self.init(host: .ssh(String(hostAndPath[..<pathStart])), path: String(hostAndPath[pathStart...]))
                return
            }
        }
        self.init(host: .thisMac, path: key)
    }

    var key: String {
        switch host {
        case .thisMac:
            URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        case .ssh(let destination):
            Self.sshKeyScheme + destination + (path.hasPrefix("/") ? path : "/" + path)
        }
    }

    /// `host:/path` on an SSH host, the form `scp` and `rsync` accept; the plain path on this Mac.
    var copyablePath: String {
        switch host {
        case .thisMac: path
        case .ssh(let destination): "\(destination):\(path)"
        }
    }

    /// Whether the folder exists on this Mac; always false on an SSH host.
    var folderExistsOnThisMac: Bool {
        guard host == .thisMac else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// A folder on an SSH host is not checked; the SSH command reports it when it is gone.
    var canStartSessions: Bool {
        host != .thisMac || folderExistsOnThisMac
    }
}
