import Foundation

extension ConversationStore {
    /// Every CLI that runs a session of the project: its tabs' own, and those running in tmux with no tab open.
    func activitySummary(forProjectDirectoryKey projectDirectoryKey: String) -> SessionActivitySummary {
        let runningTabs = terminalSessions.filter { $0.projectDirectoryKey == projectDirectoryKey && !$0.hasExited }
        let conversationIDsWithRunningTab = Set(runningTabs.compactMap { $0.conversation?.id })
        let detachedActivities = conversations
            .filter {
                $0.projectDirectoryKey == projectDirectoryKey
                    && !conversationIDsWithRunningTab.contains($0.id)
                    && isRunningInTmux($0)
            }
            .map { detachedCLIActivities[$0.id] }
        return SessionActivitySummary(activities: runningTabs.map(\.cliActivity) + detachedActivities)
    }
}
