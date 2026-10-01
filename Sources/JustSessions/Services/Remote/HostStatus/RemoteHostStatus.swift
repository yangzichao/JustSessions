import Foundation

/// What a remote host runs, as of its last refresh.
struct RemoteHostStatus: Equatable, Sendable {
    /// The tmux sessions JustSessions started there that still run.
    let tmuxSessionNames: Set<String>
    /// The tools whose CLI the host's login shell finds; nil when the output did not say.
    let installedProviders: Set<ConversationProvider>?
}
