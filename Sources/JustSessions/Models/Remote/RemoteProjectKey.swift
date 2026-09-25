import Foundation

/// Projects on a remote host are keyed as `ssh://<host><absolute path>`, so they never merge with a local
/// folder at the same path. The key is what grouping, pinning, and custom project names use.
enum RemoteProjectKey {
    private static let scheme = "ssh://"

    static func key(host: String, projectPath: String) -> String {
        let absolutePath = projectPath.hasPrefix("/") ? projectPath : "/" + projectPath
        return scheme + host + absolutePath
    }

    /// The host and remote path of a remote project key, or nil for a local project path.
    static func location(ofKey key: String) -> (host: String, projectPath: String)? {
        guard key.hasPrefix(scheme) else { return nil }
        let hostAndPath = key.dropFirst(scheme.count)
        guard let pathStart = hostAndPath.firstIndex(of: "/") else { return nil }
        let host = String(hostAndPath[..<pathStart])
        guard !host.isEmpty else { return nil }
        return (host, String(hostAndPath[pathStart...]))
    }

    /// `host:/path`, the form `scp` and `rsync` accept.
    static func copyablePath(ofKey key: String) -> String {
        guard let location = location(ofKey: key) else { return key }
        return "\(location.host):\(location.projectPath)"
    }
}
