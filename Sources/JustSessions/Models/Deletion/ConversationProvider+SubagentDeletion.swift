import Foundation

extension ConversationProvider {
    /// Whether deleting a session also deletes the sessions of the subagents it started, at any depth. Claude Code and
    /// Pi keep them in the folder that goes with the session, on this Mac and on SSH hosts, and `codex delete` and
    /// `opencode session delete` delete a session's descendants. Antigravity's subagents are conversations of their
    /// own, which stay; Kiro records no parent, so none is ever listed under a session.
    var deletesSubagentsWithSession: Bool {
        switch self {
        case .claude, .pi, .codex, .opencode: true
        case .antigravity, .kiro: false
        }
    }
}
