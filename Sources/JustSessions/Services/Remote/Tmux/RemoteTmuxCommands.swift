import Foundation

/// tmux commands for a remote host's JustSessions sessions, run through the login shell so `tmux` is found
/// wherever the host's profile puts it.
enum RemoteTmuxCommands {
    static func renameSessionCommand(from oldName: String, to newName: String, on host: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand(
            "tmux rename-session -t \(ShellQuoting.quoted(oldName)) \(ShellQuoting.quoted(newName)) 2>/dev/null; true",
            on: host
        )
    }

    /// Exits with 0 only while the host's tmux runs the session; a host without tmux fails it too. `=` matches the
    /// whole name, not a session whose name starts with it.
    static func hasSessionCommand(_ name: String, on host: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand(
            "tmux has-session -t \(ShellQuoting.quoted("=" + name)) 2>/dev/null",
            on: host
        )
    }

    /// Replaces each client attached to the session with a new client in the same terminal, which tmux asks for the
    /// terminal's colors as it attaches. The session and its CLI run on. Exits with 0 once the clients have detached.
    static func reattachClientsCommand(_ name: String, on host: String) -> String {
        let target = ShellQuoting.quoted("=" + name)
        let attach = "exec tmux attach-session -t \(target)"
        return RemoteCLICommandBuilder.loginShellCommand(
            "tmux detach-client -s \(target) -E \(ShellQuoting.quoted(attach))",
            on: host
        )
    }

    static func killSessionCommand(_ name: String, on host: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand(
            "tmux kill-session -t \(ShellQuoting.quoted(name)) 2>/dev/null; true",
            on: host
        )
    }

    /// Gives every JustSessions session on the host the prefix keys `RemoteTmuxPrefixOptions` describes, so a new
    /// choice reaches tabs already attached and sessions no tab shows, which you may attach to yourself.
    static func setPrefixOptionsCommand(usingHostPrefix: Bool, on host: String) -> String {
        // `set-option` takes a pane: `=name:` is exactly that session, where a bare `=name` finds nothing.
        let setOptions = RemoteTmuxPrefixOptions.setOptionCommands(usingHostPrefix: usingHostPrefix, target: "\"=$name:\"")
        return RemoteCLICommandBuilder.loginShellCommand(
            "tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^\(TmuxSessionName.prefix)'"
                + " | while IFS= read -r name; do tmux \(setOptions.joined(separator: " \\; ")) 2>/dev/null; done; true",
            on: host
        )
    }
}
