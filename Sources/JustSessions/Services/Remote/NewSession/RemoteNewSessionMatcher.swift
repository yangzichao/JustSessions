import Foundation

/// A "new session" tab on a remote host, copied out of its `TerminalSession` for matching.
struct WaitingRemoteNewSessionTab: Equatable {
    let terminalID: UUID
    let host: String
    let provider: ConversationProvider
    let projectPath: String
    let launchedAt: Date
    let sessionIDsKnownAtLaunch: Set<String>
}

/// The local new-session search watches the CLI process's open files, which an `ssh` tab cannot offer.
/// A remote tab instead takes the first session that appears in its project, for its tool, after it started.
enum RemoteNewSessionMatcher {
    /// Tabs are served oldest first, and each session goes to at most one tab.
    static func matches(
        for waitingTabs: [WaitingRemoteNewSessionTab],
        in conversations: [Conversation],
        alreadyLinkedConversationIDs: Set<String>
    ) -> [UUID: Conversation] {
        var takenConversationIDs = alreadyLinkedConversationIDs
        var matches: [UUID: Conversation] = [:]
        for tab in waitingTabs.sorted(by: { $0.launchedAt < $1.launchedAt }) {
            let candidate = conversations
                .filter {
                    $0.remoteHost == tab.host
                        && $0.provider == tab.provider
                        && $0.projectPath == tab.projectPath
                        && !tab.sessionIDsKnownAtLaunch.contains($0.sessionID)
                        && !takenConversationIDs.contains($0.id)
                }
                .min { $0.updatedAt < $1.updatedAt }
            guard let candidate else { continue }
            takenConversationIDs.insert(candidate.id)
            matches[tab.terminalID] = candidate
        }
        return matches
    }
}
