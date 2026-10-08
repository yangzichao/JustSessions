import Foundation

extension ConversationStore {
    /// Every CLI that runs a session of the project: its tabs' own, and those running in tmux with no tab open.
    /// A plain terminal runs no session, so it does not count.
    func activitySummary(forProjectDirectoryKey projectDirectoryKey: String) -> SessionActivitySummary {
        let runningTabs = terminalSessions.filter {
            $0.projectDirectoryKey == projectDirectoryKey && !$0.isPlainTerminal && $0.isRunning
        }
        let conversationIDsWithRunningTab = Set(runningTabs.compactMap { $0.conversation?.id })
        let detachedStatuses = conversationIndex.conversations(inProject: projectDirectoryKey)
            .filter { isRunningInTmux($0) && !conversationIDsWithRunningTab.contains($0.id) }
            .map(detachedCLIStatus(of:))
        return SessionActivitySummary(statuses: runningTabs.map(\.runStatus) + detachedStatuses)
    }
}
