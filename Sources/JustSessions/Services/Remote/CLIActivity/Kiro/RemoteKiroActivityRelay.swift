import Foundation

/// Tells a tab what a Kiro CLI on an SSH host does. Kiro marks a turn under way only in its turn-markers folder on the
/// host (see `KiroTurnMarkers`), and its terminal title says nothing of it. So a tab's tmux session starts this relay
/// beside the CLI, as Claude Code's (`RemoteClaudeActivityRelay`). Once a second it lists the markers, and when one
/// names a process at or below the relay's pane, the CLI is working; otherwise it is idle. When that changes, it sets
/// it as the window option the session's title shows; see `RemoteCLIActivityTitle`. Without the folder, as from a Kiro
/// too old to keep one, it sets nothing, so the tab tells nothing rather than seeming idle.
///
/// The pane's login shell starts it before the CLI, so it sees an `XDG_DATA_HOME` the host's startup files set. It runs
/// in `sh`, as that shell may be fish. It starts once with the pane and ends with the pane's process, so it goes on
/// while no tab is attached, and a tab that reattaches starts no second one. Between reads it costs one `sleep`, and
/// while a marker exists, one `ps` of every process, read by `awk` up each marker's parents; `ps -A -o pid= -o ppid=`
/// lists them on Linux, macOS, and BusyBox.
enum RemoteKiroActivityRelay {
    static let launchCommand = "sh -c \(ShellQuoting.quoted("(\n\(script)\n) </dev/null >/dev/null 2>&1 &"))"

    static let script = #"""
        pane_pid=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_pid}') || exit 0
        case $(uname -s) in
        Darwin) markers="$HOME/Library/Application Support/kiro-cli/run/turn-markers" ;;
        *) markers="${XDG_DATA_HOME:-$HOME/.local/share}/kiro-cli/run/turn-markers" ;;
        esac
        shown=
        while kill -0 "$pane_pid" 2>/dev/null; do
          activity=
          if [ -d "$markers" ]; then
            activity=\#(KiroTurnMarkers.idleName)
            pids=
            for marker in "$markers"/*-*.json; do
              [ -f "$marker" ] || continue
              name=${marker##*/}
              pids="$pids ${name%%-*}"
            done
            if [ -n "$pids" ] && ps -A -o pid= -o ppid= 2>/dev/null | awk -v root="$pane_pid" -v pids="$pids" '
              { parent[$1] = $2 }
              END {
                count = split(pids, list, " ")
                for (i = 1; i <= count; i++) {
                  p = list[i]
                  for (depth = 0; depth < 64 && p != "" && p != 1; depth++) {
                    if (p == root) exit 0
                    p = parent[p]
                  }
                }
                exit 1
              }'; then
              activity=\#(KiroTurnMarkers.workingName)
            fi
          fi
          if [ -n "$activity" ] && [ "$activity" != "$shown" ]; then
            tmux set-option -wq -t "$TMUX_PANE" \#(RemoteCLIActivityTitle.optionName) "$activity:" \; refresh-client -S
            shown=$activity
          fi
          sleep 1
        done
        """#
}
