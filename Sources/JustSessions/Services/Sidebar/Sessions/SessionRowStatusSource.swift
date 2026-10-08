import Foundation

/// What a session's sidebar row shows as its CLI's status. See `ConversationStore.sessionRowStatusSource(of:)`.
enum SessionRowStatusSource {
    /// A tab's CLI, running or ended. The row follows the tab itself, which tells its views when its CLI changes.
    case tab(TerminalSession)
    /// A CLI running in tmux with no tab open.
    case detachedCLI(SessionRunStatus)

    @MainActor var status: SessionRunStatus {
        switch self {
        case .tab(let tab): tab.runStatus
        case .detachedCLI(let status): status
        }
    }
}
