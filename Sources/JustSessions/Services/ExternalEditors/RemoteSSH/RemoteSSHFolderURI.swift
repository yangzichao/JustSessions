import Foundation

/// The `vscode-remote://ssh-remote+<host><path>` URI that a VS Code-family editor's `--folder-uri` opens over SSH.
/// The host part follows the Remote - SSH extension's own encoding (`HostInfo.toAuthorityString`): a lowercase host
/// name as it is, and anything with a user, a capital letter, `/`, `\`, or `+` as hex-encoded JSON, because VS Code
/// lowercases URI authorities.
enum RemoteSSHFolderURI {
    static func string(destination: String, path: String) -> String {
        let absolutePath = path.hasPrefix("/") ? path : "/" + path
        let encodedPath = absolutePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? absolutePath
        return "vscode-remote://ssh-remote+" + authorityHost(destination: destination) + encodedPath
    }

    /// `destination` is `host` or `user@host`, as `SessionHost.ssh` keeps it.
    private static func authorityHost(destination: String) -> String {
        var user: String?
        var hostName = destination
        if let at = destination.lastIndex(of: "@") {
            user = String(destination[..<at])
            hostName = String(destination[destination.index(after: at)...])
        }
        let needsEncoding = user != nil
            || hostName.lowercased() != hostName
            || hostName.contains(where: { "/\\+".contains($0) })
        guard needsEncoding else { return hostName }

        var hostInfo = ["hostName": hostName]
        if let user { hostInfo["user"] = user }
        let jsonOptions: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
        guard let json = try? JSONSerialization.data(withJSONObject: hostInfo, options: jsonOptions) else { return hostName }
        return json.map { String(format: "%02x", $0) }.joined()
    }
}
