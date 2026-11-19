import Foundation

extension ConversationStore {
    var otherWindowStores: [ConversationStore] {
        windowRegistry.stores.filter { $0 !== self }
    }

    func runningTerminalInAnotherWindow(for conversation: Conversation) -> TerminalSession? {
        otherWindowRunningTerminal(for: conversation)?.tab
    }

    func otherWindowRunningTerminal(for conversation: Conversation) -> (store: ConversationStore, tab: TerminalSession)? {
        otherWindowStores.lazy.compactMap { store in store.runningTerminal(for: conversation).map { (store, $0) } }.first
    }

    @discardableResult
    func showRunningTerminalInAnotherWindow(for conversation: Conversation) -> Bool {
        guard let (store, tab) = otherWindowRunningTerminal(for: conversation) else { return false }
        store.selectTerminal(tab.id)
        windowRegistry.bringForward(store)
        return true
    }

    func hasTerminalInAnotherWindow(for conversation: Conversation) -> Bool {
        otherWindowStores.contains { store in
            store.terminalSessions.contains { $0.conversation?.id == conversation.id }
        }
    }

    var runningTerminalsInOtherWindows: [String: TerminalSession] {
        var tabsByConversationID: [String: TerminalSession] = [:]
        for store in otherWindowStores {
            for tab in store.terminalSessions where tab.isRunning {
                guard let conversationID = tab.conversation?.id, tabsByConversationID[conversationID] == nil else { continue }
                tabsByConversationID[conversationID] = tab
            }
        }
        return tabsByConversationID
    }
}
