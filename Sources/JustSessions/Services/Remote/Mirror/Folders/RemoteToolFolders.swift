import Foundation

/// Where an SSH host keeps each tool's session files, found from the host's login shell by `RemoteToolFoldersLookup`.
/// A path is absolute, or relative to the host's home when the lookup could not tell. Antigravity keeps the standard
/// folder, and OpenCode's database is found by its own snapshot command; see `OpenCodeRemoteDatabaseLocation`.
struct RemoteToolFolders: Codable, Equatable, Sendable {
    var claude: String
    var codex: String
    var kiro: String
    var pi: String

    /// The folders of a host that sets none of the tools' variables, relative to its home.
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

    /// `rsync`'s source for the folder's contents. The host's shell reads the path again, so one with a space or
    /// another special character is quoted.
    func rsyncSource(host: String, provider: ConversationProvider) -> String {
        "\(host):\(Self.quotedIfNeeded(path(for: provider)))/"
    }

    /// The folder in a POSIX `sh` script, a relative one from `$HOME`.
    func shellPath(for provider: ConversationProvider) -> String {
        let path = path(for: provider)
        return path.hasPrefix("/") ? ShellQuoting.quoted(path) : "\"$HOME\"/" + ShellQuoting.quoted(path)
    }

    /// The folder with this Mac's stand-in for the host's home in place of a relative path's home, for tests.
    func localPath(for provider: ConversationProvider, sourceHome: String) -> String {
        let path = path(for: provider)
        return path.hasPrefix("/") ? path : "\(sourceHome)/\(path)"
    }

    private static func quotedIfNeeded(_ path: String) -> String {
        let plain = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/._-+@%,:"))
        return path.unicodeScalars.allSatisfy { plain.contains($0) && $0.isASCII } ? path : ShellQuoting.quoted(path)
    }
}
