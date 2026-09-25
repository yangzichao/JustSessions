import Foundation

enum ConversationProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case claude = "Claude Code"
    case codex = "Codex"
    case antigravity = "Antigravity"

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .claude: "asterisk"
        case .codex: "terminal"
        case .antigravity: "sparkle"
        }
    }

    var supportsBranchFromLauncher: Bool { self != .antigravity }
    var supportsDeletionFromLauncher: Bool { self != .antigravity }
    /// Tools whose sessions are listed and resumed on remote hosts.
    var supportsRemoteHosts: Bool { self != .antigravity }
}

struct Conversation: Identifiable, Sendable {
    let provider: ConversationProvider
    let sessionID: String
    let projectPath: String
    let suggestedTitle: String
    let updatedAt: Date
    /// For a local session, the file the CLI wrote. For a remote one, its copy in the local mirror.
    let sourceFile: URL
    /// The SSH host the session lives on, or nil for a session on this Mac.
    var remoteHost: String? = nil

    var id: String {
        let localID = "\(provider.rawValue):\(sessionID)"
        guard let remoteHost else { return localID }
        return "\(localID)@\(remoteHost)"
    }
    var isRemote: Bool { remoteHost != nil }
    var supportsDeletionFromLauncher: Bool { provider.supportsDeletionFromLauncher }

    func withSuggestedTitle(_ title: String) -> Conversation {
        Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: title,
            updatedAt: updatedAt,
            sourceFile: sourceFile,
            remoteHost: remoteHost
        )
    }
    func onRemoteHost(_ host: String) -> Conversation {
        Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: suggestedTitle,
            updatedAt: updatedAt,
            sourceFile: sourceFile,
            remoteHost: host
        )
    }
    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }
    var projectDirectoryKey: String {
        if let remoteHost { return RemoteProjectKey.key(host: remoteHost, projectPath: projectPath) }
        return URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath().path
    }
    /// A remote folder is not checked; the SSH command reports it when it is gone.
    var isProjectAvailable: Bool {
        if isRemote { return true }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: projectPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
