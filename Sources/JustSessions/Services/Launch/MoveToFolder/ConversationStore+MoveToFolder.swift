import Foundation

/// **Move to** in a session's menu. It resumes a Claude Code session in a tab with `/cd <folder>` as its first message,
/// so Claude Code moves the session and, in a folder the session hasn't worked in, asks first in the tab. The sidebar
/// lists the session under its new folder once a refresh reads the transcript's `relocated` line.
extension ConversationStore {
    /// Off while the session's CLI runs, in a tab of any window or in tmux: `/cd` typed into a running CLI could join a
    /// half-written prompt or wait behind a turn.
    func canMoveSession(_ conversation: Conversation) -> Bool {
        conversation.provider.movesSessionsToOtherFolders
            && canLaunch(conversation, action: .resume)
            && !canEndSession(conversation)
    }

    func moveDestinations(for conversation: Conversation) -> [SessionMoveDestination] {
        SessionMoveDestination.destinations(for: conversation, among: sidebarProjectGroups)
    }

    /// Does nothing for the session's own folder, where `/cd` would only say it is already there.
    func moveSession(_ conversation: Conversation, toFolder folderPath: String) {
        guard canMoveSession(conversation),
            ProjectLocation(host: conversation.host, path: folderPath).key != conversation.projectDirectoryKey
        else { return }
        resume(conversation, appendedArguments: conversation.provider.moveToFolderArguments(folderPath))
    }
}
