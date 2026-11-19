import Foundation

struct ProjectLocation: Hashable, Sendable {
    private static let sshKeyScheme = "ssh://"

    let host: SessionHost
    let path: String

    init(host: SessionHost, path: String) {
        self.host = host
        self.path = path
    }

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

    var folderExistsOnThisMac: Bool {
        guard host == .thisMac else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    var canStartSessions: Bool {
        host != .thisMac || folderExistsOnThisMac
    }
}
