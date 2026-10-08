import Foundation

/// A session runs in at most one tab across the app's windows. Resuming a session another window's tab runs shows
/// that tab in its window. This window's rows, project summaries, and activity sync count that tab as the session's
/// own, so the session is not taken for a CLI running in tmux with no tab open.
extension ConversationStore {
    /// The other open windows' stores, oldest first.
    private var otherWindowStores: [ConversationStore] {
        windowRegistry.stores.filter { $0 !== self }
    }

    /// The tab in another window whose CLI still runs the session, or starts it once shown.
    func runningTerminalInAnotherWindow(for conversation: Conversation) -> TerminalSession? {
        otherWindowStores.lazy.compactMap { $0.runningTerminal(for: conversation) }.first
    }

    /// Selects the session's tab in the other window that runs it and brings that window forward. Returns false when
    /// no other window runs the session.
    @discardableResult
    func showRunningTerminalInAnotherWindow(for conversation: Conversation) -> Bool {
        for store in otherWindowStores {
            guard let tab = store.runningTerminal(for: conversation) else { continue }
            store.selectTerminal(tab.id)
            windowRegistry.bringForward(store)
            return true
        }
        return false
    }

    /// Whether another window has a tab of the session, its CLI running or ended.
    func hasTerminalInAnotherWindow(for conversation: Conversation) -> Bool {
        otherWindowStores.contains { store in
            store.terminalSessions.contains { $0.conversation?.id == conversation.id }
        }
    }

    /// Other windows' tabs whose CLI runs now, by the session it runs.
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
