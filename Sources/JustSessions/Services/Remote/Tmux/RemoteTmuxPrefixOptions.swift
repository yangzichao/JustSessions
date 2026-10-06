import Foundation

/// The prefix keys of a JustSessions tmux session on an SSH host. By default the session has none, so Ctrl-B and every
/// other key reaches the CLI. On a host set to use its tmux prefix, the session's own setting is removed instead, and
/// it falls back to the host's global prefix keys, the ones its `~/.tmux.conf` sets. See `RemoteHostsUsingTmuxPrefix`.
enum RemoteTmuxPrefixOptions {
    /// `prefix2` too: a second prefix set in `~/.tmux.conf` would otherwise still take its key from the CLI.
    static let optionNames = ["prefix", "prefix2"]

    /// tmux `set-option` commands for the session `target` names, or without one for the session of the command
    /// they follow.
    static func setOptionCommands(usingHostPrefix: Bool, target: String? = nil) -> [String] {
        let targetArguments = target.map { " -t \($0)" } ?? ""
        return optionNames.map { name in
            usingHostPrefix ? "set-option\(targetArguments) -u \(name)" : "set-option\(targetArguments) \(name) None"
        }
    }
}
