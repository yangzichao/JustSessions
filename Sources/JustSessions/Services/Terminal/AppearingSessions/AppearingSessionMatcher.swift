import Foundation

/// Links waiting "New session" and "Branch" tabs whose CLI leaves no trace of the session it writes: tabs on SSH
/// hosts, whose `ssh` process says nothing, unless they started with their session's id (see
/// `RemoteClaudeSessionIDFlagSupport`), and tabs of tools that link by appearance on this Mac (see
/// `ConversationProvider.linksNewSessionsByAppearance`). Such a tab takes the first session that appears in its
/// project, for its tool, after it started.
enum AppearingSessionMatcher {
    /// Tabs are served oldest first, and each session goes to at most one tab.
    static func matches(
        for waitingTabs: [WaitingTabForAppearingSession],
        in conversations: [Conversation],
        alreadyLinkedConversationIDs: Set<String>
    ) -> [UUID: Conversation] {
        var takenConversationIDs = alreadyLinkedConversationIDs
        var matches: [UUID: Conversation] = [:]
        for tab in waitingTabs.sorted(by: { $0.launchedAt < $1.launchedAt }) {
            let candidate = conversations
                .filter {
                    $0.host == tab.host
                        && $0.provider == tab.provider
                        && $0.projectPath == tab.projectPath
                        && !tab.sessionIDsKnownAtLaunch.contains($0.sessionID)
                        && !takenConversationIDs.contains($0.id)
                        && wasActiveSinceLaunch($0, of: tab)
                }
                .min { $0.updatedAt < $1.updatedAt }
            guard let candidate else { continue }
            takenConversationIDs.insert(candidate.id)
            matches[tab.terminalID] = candidate
        }
        return matches
    }

    /// On this Mac, a session last written before the tab started is one the app had not listed yet, not the
    /// tab's. An SSH host's clock may differ from this Mac's, so there the times are not compared.
    private static func wasActiveSinceLaunch(_ conversation: Conversation, of tab: WaitingTabForAppearingSession) -> Bool {
        tab.host != .thisMac || conversation.updatedAt >= tab.launchedAt
    }
}
