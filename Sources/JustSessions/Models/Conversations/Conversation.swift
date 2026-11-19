import Foundation

struct Conversation: Identifiable, Sendable, Equatable {
    let provider: ConversationProvider
    let sessionID: String
    let projectPath: String
    private(set) var suggestedTitle: String
    let updatedAt: Date
    let sourceFile: URL
    private(set) var host: SessionHost
    let parentSessionID: String?
    private(set) var id: String
    private(set) var projectDirectoryKey: String
    let model: SessionModel?

    init(
        provider: ConversationProvider,
        sessionID: String,
        projectPath: String,
        suggestedTitle: String,
        updatedAt: Date,
        sourceFile: URL,
        host: SessionHost = .thisMac,
        parentSessionID: String? = nil,
        model: SessionModel? = nil
    ) {
        self.provider = provider
        self.sessionID = sessionID
        self.projectPath = projectPath
        self.suggestedTitle = suggestedTitle
        self.updatedAt = updatedAt
        self.sourceFile = sourceFile
        self.host = host
        self.parentSessionID = parentSessionID
        self.model = model
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
            host: host,
            parentSessionID: parentSessionID,
            model: model
        )
    }
    var isSubagent: Bool { parentSessionID != nil }
    var parentID: String? {
        parentSessionID.map { Self.id(provider: provider, sessionID: $0, host: host) }
    }
    var projectLocation: ProjectLocation {
        ProjectLocation(host: host, path: projectPath)
    }
    var isProjectAvailable: Bool { projectLocation.canStartSessions }

    static func id(provider: ConversationProvider, sessionID: String, host: SessionHost) -> String {
        let providerSessionID = "\(provider.rawValue):\(sessionID)"
        guard let sshDestination = host.sshDestination else { return providerSessionID }
        return "\(providerSessionID)@\(sshDestination)"
    }
}
