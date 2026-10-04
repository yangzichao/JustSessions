import Foundation

extension ConversationStore {
    /// Links the tab to the session its CLI is in: a new session's tab once the session is known, or a tab whose CLI
    /// moved to another session. The tab takes the session's title, its tmux session the session's name, and the
    /// session's row in the sidebar, Resume, and the next launch find the tab.
    func link(_ session: TerminalSession, to conversation: Conversation) {
        session.synchronize(conversation: conversation, displayTitle: title(for: conversation))
        adoptSessionTmuxName(for: session)
        // Sidebar rows look up open terminals through the store, which does not see a tab's own changes.
        persistOpenTabs()
        objectWillChange.send()
    }
}
