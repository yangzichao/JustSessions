import Foundation

/// How an editor opens a project folder on an SSH host with its own remote development: a link that names the host
/// and the folder's absolute path there. The editor connects with your own `ssh`, so `~/.ssh/config` applies, and
/// installs its server on the host the first time. Editors with no SSH remote mode, such as Sublime Text and Xcode,
/// have none.
enum RemoteProjectOpening: Hashable, Sendable {
    /// A VS Code fork, through the URL scheme its app registers. Needs the editor's SSH extension, such as Microsoft's
    /// Remote - SSH in VS Code or Open Remote - SSH in VSCodium; Antigravity IDE has one built in.
    case vscodeRemoteSSH(urlScheme: String)
    /// Zed's own SSH remoting, in Zed 0.159 and later.
    case zed
    /// JetBrains Toolbox's SSH remote development, which sets up the IDE with this product code on the host. Toolbox
    /// opens the link, not the IDE.
    case jetBrainsToolbox(productCode: String)

    static let jetBrainsToolboxURLScheme = "jetbrains"

    var opensThroughJetBrainsToolbox: Bool {
        if case .jetBrainsToolbox = self { return true }
        return false
    }

    /// The link that opens the folder at `path` on `host`, as the host list keeps it: a `Host` alias from
    /// `~/.ssh/config`, a host name, or `user@hostname`. Nil when `path` is not absolute, or when the editor's link
    /// can't name the host.
    func link(host: String, path: String) -> URL? {
        guard path.hasPrefix("/") else { return nil }
        let destination = SSHDestination(host)
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        switch self {
        case .vscodeRemoteSSH(let urlScheme):
            return URL(string: "\(urlScheme)://vscode-remote/ssh-remote+\(destination.vscodeRemoteAuthority)\(encodedPath)?windowId=_blank")
        case .zed:
            guard let zedDestination = destination.zedDestination else { return nil }
            return URL(string: "zed://ssh/\(zedDestination)\(encodedPath)")
        case .jetBrainsToolbox(let productCode):
            // Without `p`, Toolbox runs `ssh` with the port your SSH configuration gives; without `u`, its user.
            var parameters = [("h", destination.hostName)]
            if let user = destination.user { parameters.append(("u", user)) }
            parameters += [("launchIde", "true"), ("ideHint", productCode), ("projectHint", path)]
            let query = parameters.map { "\($0)=\(Self.encodedQueryValue($1))" }.joined(separator: "&")
            return URL(string: "\(Self.jetBrainsToolboxURLScheme)://gateway/ssh/environment?\(query)")
        }
    }

    /// Everything but unreserved characters, slashes, and colons is encoded, so `+`, `&`, and `=` in a path stay
    /// part of it.
    private static func encodedQueryValue(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreservedCharacters.union(CharacterSet(charactersIn: "/:")))
            ?? value
    }
}

private let asciiLettersAndDigits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
private let unreservedCharacters = CharacterSet(charactersIn: asciiLettersAndDigits + "-._~")

/// An `ssh` destination, split as `ssh` splits it, at its last `@`.
private struct SSHDestination {
    let destination: String
    let user: String?
    let hostName: String

    init(_ destination: String) {
        self.destination = destination
        if let at = destination.lastIndex(of: "@") {
            user = String(destination[..<at])
            hostName = String(destination[destination.index(after: at)...])
        } else {
            user = nil
            hostName = destination
        }
    }

    /// The host after `ssh-remote+`. Remote - SSH, Microsoft's and Open Remote - SSH alike, reads a plain host back as
    /// written. Any other host, such as one with capital letters, which the link's authority doesn't keep, or an IPv6
    /// address, goes as hex-encoded JSON, the form Remote - SSH writes for such hosts itself.
    var vscodeRemoteAuthority: String {
        let plainCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-_@")
        if destination.unicodeScalars.allSatisfy(plainCharacters.contains) { return destination }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let json = try? encoder.encode(RemoteSSHHost(hostName: hostName, user: user)) else { return destination }
        return json.map { String(format: "%02x", $0) }.joined()
    }

    /// `[user@]host` for a Zed link, with an IPv6 address in brackets. Nil for a host Zed's link can't carry.
    var zedDestination: String? {
        let host: String
        if hostName.contains(":") {
            guard hostName.allSatisfy({ $0.isHexDigit || $0 == ":" || $0 == "." }) else { return nil }
            host = "[\(hostName)]"
        } else {
            let hostCharacters = CharacterSet(charactersIn: asciiLettersAndDigits + ".-_")
            guard !hostName.isEmpty, hostName.unicodeScalars.allSatisfy(hostCharacters.contains) else { return nil }
            host = hostName
        }
        guard let user else { return host }
        guard !user.isEmpty, let encodedUser = user.addingPercentEncoding(withAllowedCharacters: unreservedCharacters)
        else { return nil }
        return "\(encodedUser)@\(host)"
    }
}

/// What Remote - SSH decodes from a hex-encoded authority.
private struct RemoteSSHHost: Encodable {
    let hostName: String
    let user: String?
}
