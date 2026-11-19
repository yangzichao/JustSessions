import Foundation

extension ConversationStore {
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
