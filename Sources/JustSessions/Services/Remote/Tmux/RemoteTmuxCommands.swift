import Foundation

/// tmux commands for a remote host's JustSessions sessions, run through the login shell so `tmux` is found
/// wherever the host's profile puts it.
enum RemoteTmuxCommands {
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

    /// Gives every JustSessions session on the host the prefix keys `RemoteTmuxPrefixOptions` describes, so a new
    /// choice reaches tabs already attached and sessions no tab shows, which you may attach to yourself.
    static func setPrefixOptionsCommand(usingHostPrefix: Bool) -> String {
        // `set-option` takes a pane: `=name:` is exactly that session, where a bare `=name` finds nothing.
        let setOptions = RemoteTmuxPrefixOptions.setOptionCommands(usingHostPrefix: usingHostPrefix, target: "\"=$name:\"")
        return RemoteCLICommandBuilder.loginShellCommand(
            "tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^\(TmuxSessionName.prefix)'"
                + " | while IFS= read -r name; do tmux \(setOptions.joined(separator: " \\; ")) 2>/dev/null; done; true"
        )
    }
}
