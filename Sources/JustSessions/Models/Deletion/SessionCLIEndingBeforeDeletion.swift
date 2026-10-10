import Foundation

/// What Close and delete ends before it deletes a session; see `ConversationStore+ClosingAndDeleting`.
enum SessionCLIEndingBeforeDeletion: Equatable {
    /// A tab shows the session, in this window or another. It closes, and its CLI ends.
    case closingTab
    /// No tab shows the session, but its CLI still runs in tmux on its host. The CLI ends.
    case endingCLIInTmux
}
