import Foundation

enum AppearingSessionMatcher {
    static func matches(
        for waitingTabs: [WaitingTabForAppearingSession],
        in conversations: [Conversation],
        takenConversationIDs: Set<String>
    ) -> [UUID: Conversation] {
        var takenConversationIDs = takenConversationIDs
        var matches: [UUID: Conversation] = [:]
        for tab in waitingTabs.sorted(by: { $0.launchedAt < $1.launchedAt }) {
            let candidate =
                conversations
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

    /// An SSH host's clock may differ from this Mac's, so there the times are not compared.
    private static func wasActiveSinceLaunch(_ conversation: Conversation, of tab: WaitingTabForAppearingSession) -> Bool {
        tab.host != .thisMac || conversation.updatedAt >= tab.launchedAt
    }
}
