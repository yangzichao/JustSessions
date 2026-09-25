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
}
