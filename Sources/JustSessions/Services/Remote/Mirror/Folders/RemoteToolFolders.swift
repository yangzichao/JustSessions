import Foundation

struct RemoteToolFolders: Codable, Equatable, Sendable {
    var claude: String
    var codex: String
    var kiro: String
    var pi: String

    static let standard = RemoteToolFolders(
        claude: RemoteSessionMirror.remoteFolder(for: .claude),
        codex: RemoteSessionMirror.remoteFolder(for: .codex),
        kiro: RemoteSessionMirror.remoteFolder(for: .kiro),
        pi: RemoteSessionMirror.remoteFolder(for: .pi)
    )

    func path(for provider: ConversationProvider) -> String {
        switch provider {
        case .claude: claude
        case .codex: codex
        case .kiro: kiro
        case .pi: pi
        case .antigravity, .opencode: RemoteSessionMirror.remoteFolder(for: provider)
        }
    }

    var kiroV3: String { (kiro as NSString).deletingLastPathComponent }

    /// `rsync`'s source for the folder's contents. The host's shell reads the path again, so one with a space or
    /// another special character is quoted.
    func rsyncSource(host: String, provider: ConversationProvider) -> String {
        Self.rsyncSource(host: host, path: path(for: provider))
    }

    static func rsyncSource(host: String, path: String) -> String {
        "\(host):\(quotedIfNeeded(path))/"
    }

    func shellPath(for provider: ConversationProvider) -> String {
        let path = path(for: provider)
        return path.hasPrefix("/") ? ShellQuoting.quoted(path) : "\"$HOME\"/" + ShellQuoting.quoted(path)
    }

    private static func quotedIfNeeded(_ path: String) -> String {
        let plain = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/._-+@%,:"))
        return path.unicodeScalars.allSatisfy { plain.contains($0) && $0.isASCII } ? path : ShellQuoting.quoted(path)
    }
}
