import Foundation

extension ConversationStore {
    /// What a session's sidebar row shows as its CLI's status. A tab whose CLI runs comes first, the selected one
    /// among them; then another window's tab whose CLI runs; then a CLI running in tmux with no tab; then a tab whose
    /// CLI ended or has not started. Nil when nothing runs the session.
    func sessionRowStatusSource(of conversation: Conversation) -> SessionRowStatusSource? {
        let tabs = terminalSessions.filter { $0.conversation?.id == conversation.id }
        let runningTabs = tabs.filter(\.isRunning)
        if let runningTab = runningTabs.first(where: { $0.id == selectedTerminalID }) ?? runningTabs.first {
            return .tab(runningTab)
        }
        if let otherWindowTab = runningTerminalInAnotherWindow(for: conversation), otherWindowTab.isRunning {
            return .tab(otherWindowTab)
        }
        if isRunningInTmux(conversation) { return .detachedCLI(detachedCLIStatus(of: conversation)) }
        return tabs.first.map { .tab($0) }
    }
}
