import Foundation

extension ConversationStore {
    /// Every CLI that runs a session of the project: its tabs' own, those of its sessions' tabs in other windows, and
    /// those running in tmux with no tab open. A plain terminal runs no session, so it does not count.
    func activitySummary(forProjectDirectoryKey projectDirectoryKey: String) -> SessionActivitySummary {
        let runningTabs = terminalSessions.filter {
            $0.projectDirectoryKey == projectDirectoryKey && !$0.isPlainTerminal && $0.isRunning
        }
        let conversationIDsWithRunningTab = Set(runningTabs.compactMap { $0.conversation?.id })
        let otherWindowTabs = runningTerminalsInOtherWindows
        let elsewhereStatuses = conversationIndex.conversations(inProject: projectDirectoryKey)
            .filter { !conversationIDsWithRunningTab.contains($0.id) }
            .compactMap { conversation -> SessionRunStatus? in
                if let otherWindowTab = otherWindowTabs[conversation.id] { return otherWindowTab.runStatus }
                return isRunningInTmux(conversation) ? detachedCLIStatus(of: conversation) : nil
            }
        return SessionActivitySummary(statuses: runningTabs.map(\.runStatus) + elsewhereStatuses)
    }
}
