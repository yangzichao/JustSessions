import Foundation

/// tmux commands for a remote host's JustSessions sessions, run through the login shell so `tmux` is found
/// wherever the host's profile puts it.
enum RemoteTmuxCommands {
    static let listSessionsCommand = RemoteCLICommandBuilder.loginShellCommand(
        "tmux list-sessions -F '#{session_name}' 2>/dev/null; true"
    )

    static func renameSessionCommand(from oldName: String, to newName: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand(
            "tmux rename-session -t \(ShellQuoting.quoted(oldName)) \(ShellQuoting.quoted(newName)) 2>/dev/null; true"
        )
    }

    static func killSessionCommand(_ name: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand(
            "tmux kill-session -t \(ShellQuoting.quoted(name)) 2>/dev/null; true"
        )
    }

    /// Session names from `list-sessions`. Lines a shell profile prints, and sessions not started here, are ignored.
    static func appSessionNames(inListOutput output: String) -> Set<String> {
        Set(output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix(RemoteTmuxSessionName.prefix) && !$0.contains(" ") })
    }
}
