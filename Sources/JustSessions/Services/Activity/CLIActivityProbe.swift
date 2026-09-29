import Foundation

/// A CLI running on this Mac, and what it takes to ask it what it is doing.
struct CLIActivityProbe: Sendable {
    let provider: ConversationProvider
    /// The CLI's process, or 0 while it is unknown, such as just after a tab's tmux session started.
    let processID: Int32
    /// The session's file, where Codex records its turns; nil before a new session's file is known.
    let sessionFile: URL?
}

extension TerminalSession {
    /// Nil for a tab on an SSH host, whose CLI runs out of reach.
    var cliActivityProbe: CLIActivityProbe? {
        guard host == .thisMac else { return nil }
        return CLIActivityProbe(provider: provider, processID: cliProcessID, sessionFile: conversation?.sourceFile)
    }
}
