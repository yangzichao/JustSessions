import Foundation

/// Claude Code's `/clear`, and its `/resume` of another session, move a running CLI to another session. The live
/// registry says which session the tab's CLI is in now, so the tab follows it there: from then on its title, its row
/// in the sidebar, and the tmux session that Resume reattaches to all belong to that session. `/clear` keeps a name
/// chosen with `/rename`, and Claude Code writes it into the new session too, so the name comes along.
extension ConversationStore {
    /// Whether the tab is linked to `sessionID` afterwards. A session that is not listed yet gets one refresh of this
    /// Mac, and the tab follows it once a refresh lists it.
    @discardableResult
    func followClaudeSessionSwitch(of session: TerminalSession, to sessionID: String) -> Bool {
        // A new session's tab is linked by new session discovery instead.
        guard let linkedConversation = session.conversation else { return false }
        guard linkedConversation.sessionID != sessionID else { return true }
        guard let switchedConversation = conversations.first(where: {
            $0.provider == .claude && $0.host == session.host && $0.sessionID == sessionID
        }) else {
            if session.sessionIDRefreshedForAfterCLISwitch != sessionID {
                session.sessionIDRefreshedForAfterCLISwitch = sessionID
                refreshThisMac()
            }
            return false
        }
        session.synchronize(conversation: switchedConversation, displayTitle: title(for: switchedConversation))
        adoptSessionTmuxName(for: session)
        // Sidebar rows look up open terminals through the store, which does not see a tab's own changes.
        persistOpenTabs()
        objectWillChange.send()
        return true
    }
}
