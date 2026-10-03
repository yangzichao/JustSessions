import Foundation

struct Conversation: Identifiable, Sendable {
    let provider: ConversationProvider
    let sessionID: String
    let projectPath: String
    private(set) var suggestedTitle: String
    let updatedAt: Date
    /// For a session on this Mac, the file the CLI wrote. For one on an SSH host, its copy in the local mirror.
    let sourceFile: URL
    private(set) var host: SessionHost
    /// A session on an SSH host adds the host, so the same session id on two hosts stays two sessions.
    private(set) var id: String
    /// Worked out once: on this Mac it resolves symlinks on disk, and the sidebar asks for it for every session.
    private(set) var projectDirectoryKey: String

    init(
        provider: ConversationProvider,
        sessionID: String,
        projectPath: String,
        suggestedTitle: String,
        updatedAt: Date,
        sourceFile: URL,
        host: SessionHost = .thisMac
    ) {
        self.provider = provider
        self.sessionID = sessionID
        self.projectPath = projectPath
        self.suggestedTitle = suggestedTitle
        self.updatedAt = updatedAt
        self.sourceFile = sourceFile
        self.host = host
        self.id = Self.id(provider: provider, sessionID: sessionID, host: host)
        self.projectDirectoryKey = ProjectLocation(host: host, path: projectPath).key
    }

    func withSuggestedTitle(_ title: String) -> Conversation {
        var renamed = self
        renamed.suggestedTitle = title
        return renamed
    }
    func onHost(_ host: SessionHost) -> Conversation {
        Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: suggestedTitle,
            updatedAt: updatedAt,
            sourceFile: sourceFile,
            host: host
        )
    }
    var projectLocation: ProjectLocation {
        ProjectLocation(host: host, path: projectPath)
    }
    var isProjectAvailable: Bool { projectLocation.canStartSessions }

    private static func id(provider: ConversationProvider, sessionID: String, host: SessionHost) -> String {
        let providerSessionID = "\(provider.rawValue):\(sessionID)"
        guard let sshDestination = host.sshDestination else { return providerSessionID }
        return "\(providerSessionID)@\(sshDestination)"
    }
}
