import Foundation

struct Conversation: Identifiable, Sendable {
    let provider: ConversationProvider
    let sessionID: String
    let projectPath: String
    private(set) var suggestedTitle: String
    let updatedAt: Date
    /// For a session on this Mac, the file the CLI wrote. For one on an SSH host, its copy in the local mirror.
    let sourceFile: URL
    var host: SessionHost = .thisMac

    /// A session on an SSH host adds the host, so the same session id on two hosts stays two sessions.
    var id: String {
        let providerSessionID = "\(provider.rawValue):\(sessionID)"
        guard let sshDestination = host.sshDestination else { return providerSessionID }
        return "\(providerSessionID)@\(sshDestination)"
    }
    var supportsDeletionFromLauncher: Bool { provider.supportsDeletionFromLauncher && provider.runs(on: host) }

    func withSuggestedTitle(_ title: String) -> Conversation {
        var renamed = self
        renamed.suggestedTitle = title
        return renamed
    }
    func onHost(_ host: SessionHost) -> Conversation {
        var moved = self
        moved.host = host
        return moved
    }
    var projectLocation: ProjectLocation {
        ProjectLocation(host: host, path: projectPath)
    }
    var projectDirectoryKey: String { projectLocation.key }
    var isProjectAvailable: Bool { projectLocation.canStartSessions }
}
