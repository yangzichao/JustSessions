import Foundation

/// What a remote tab runs when the host has tmux: a client attached to the session, which first starts the CLI in it
/// unless it already runs. tmux would end the session with a CLI that fails at once, and the tab's terminal would go
/// back to its own screen, which holds only tmux's `[exited]`. So a failed CLI's pane stays (`remain-on-exit failed`),
/// its client leaves it, and the script prints what the CLI printed there, ends the session, and exits with the CLI's
/// status, which the tab's ended bar shows. A CLI that exits cleanly, or a client that detaches, ends as before. A
/// client that fails and leaves no session, as when the tmux server running there is another tmux version, exits with
/// tmux's status, so the tab shows it failed rather than `Exited (0)`.
///
/// `sh` runs it, as the login shell may be fish. tmux before 3.2 has no `remain-on-exit failed` and would show
/// "Bad value" in the tab, so there the session gets neither, and a failed CLI's output is lost as before.
enum RemoteTmuxAttachScript {
    static func command(sessionName: String, paneCommand: String, sessionOptions: [String]) -> String {
        "exec sh -c \(ShellQuoting.quoted(script(sessionOptions: sessionOptions))) sh "
            + "\(ShellQuoting.quoted(sessionName)) \(ShellQuoting.quoted(paneCommand))"
    }

    static func script(sessionOptions: [String]) -> String {
        // A dead pane left behind, as when the connection dropped before the script ended it, would hold the new
        // client, so it ends first and the CLI starts again. When the pane dies, `pane-died` sends an attached client
        // off without tmux's `[detached …]` line (`-E true`), and ends the session of one no client shows. A client
        // that detached can exit with 1 too, as tmux 3.4's does, but its session is still there, so it ends the tab
        // as before.
        """
        name=$1 pane=$2
        dead() { [ "$(tmux display-message -p -t "=$name:" '#{pane_dead}' 2>/dev/null)" = 1 ]; }
        if dead; then tmux kill-session -t "=$name"; fi
        set -- \(sessionOptions.joined(separator: " \\; "))
        case $(tmux -V 2>/dev/null) in
        "tmux "[12].* | "tmux 3."[01] | "tmux 3."[01][a-z]) ;;
        *) set -- "$@" \\; set-option -w remain-on-exit failed \\; set-hook pane-died "if-shell -F '#{session_attached}' 'detach-client -E true -s =$name' 'kill-session -t =$name'" ;;
        esac
        tmux new-session -A -s "$name" "$pane" \\; "$@"
        attach_status=$?
        if dead; then
          tmux capture-pane -p -J -S - -t "=$name:" | awk '\(capturedOutputFilter)'
          status=$(tmux display-message -p -t "=$name:" '#{pane_dead_status}')
          tmux kill-session -t "=$name"
          exit "${status:-1}"
        fi
        if [ "$attach_status" != 0 ] && ! tmux has-session -t "=$name" 2>/dev/null; then exit "$attach_status"; fi
        """
    }

    /// Drops trailing blanks, the empty rows under the CLI's last line, and the "Pane is dead (status …)" line tmux
    /// writes under it.
    static let capturedOutputFilter = #"""
        { sub(/[ \t]+$/, ""); line[NR] = $0 }
        END {
          last = NR
          while (last > 0 && line[last] == "") last--
          if (last > 0 && line[last] ~ /^Pane is dead \(/) { last--; while (last > 0 && line[last] == "") last-- }
          for (row = 1; row <= last; row++) print line[row]
        }
        """#
}
