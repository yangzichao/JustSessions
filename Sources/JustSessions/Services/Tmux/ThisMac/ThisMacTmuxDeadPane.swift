import Foundation

/// A CLI that fails in tmux on this Mac keeps its pane, and what it printed there, while a tab shows it; see
/// `ThisMacTmuxServer.globalOptions`. Otherwise tmux would end the session with the CLI, and the tab's terminal would
/// go back to its own screen, which holds only tmux's `[exited]`. The tab's process is the tmux client, which stays
/// attached to the dead pane, so tmux tells the tab through its terminal title that the CLI ended, and how.
struct ThisMacTmuxDeadPane {
    /// The CLI's exit status; nil when a signal ended it.
    let exitCode: Int32?

    static let titlePrefix = "justsessions-exited:"
    /// What tmux makes the tab's terminal title: once the pane is dead, its status after `titlePrefix`; until then,
    /// the title the CLI set, as a Codex CLI names its thread with; see `CodexThreadTitle`.
    static let titleFormat = "#{?pane_dead,\(titlePrefix)#{pane_dead_status},#{pane_title}}"

    /// Nil for any other title.
    init?(terminalTitle: String) {
        guard terminalTitle.hasPrefix(Self.titlePrefix) else { return nil }
        exitCode = Int32(terminalTitle.dropFirst(Self.titlePrefix.count))
    }
}
