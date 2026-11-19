import Foundation

/// Tells a tab what a Claude Code on an SSH host does. Claude Code writes that only in its live process registry on the
/// host, `~/.claude/sessions/<pid>.json` (see `ClaudeLiveSessionRecord`), and its terminal title stays `✳ <topic>`
/// through a turn. So a tab's tmux session starts this relay beside the CLI. Once a second it reads the record whose
/// `tmux` entry names the relay's pane, as `<session>:<window id>.<pane id>`, and when its `status` or `waitingFor`
/// changes, sets them as the window option the session's title shows; see `RemoteCLIActivityTitle`. tmux passes
/// that title on to the tab over the tab's own connection, as it passes Codex's.
///
/// The pane's login shell starts it before the CLI, so it sees a `CLAUDE_CONFIG_DIR` the host's startup files set. It
/// runs in `sh`, as that shell may be fish. It starts once with the pane and ends with the pane's process, so it goes
/// on while no tab is attached, and a tab that reattaches starts no second one. It waits one second between reads,
/// reads the record, one line of JSON, with the shell's own `read`, and looks for it again only while it is missing, as
/// before Claude Code writes it. A record cut short, as one read while Claude Code writes it, leaves the last activity.
///
/// A window option works in tmux before 3.0, which has no pane options, and tmux 3.0 and later redraw the title when it
/// changes, as they don't for a session option. `refresh-client -S` makes tmux before 2.6 redraw it too.
enum RemoteClaudeActivityRelay {
    static let launchCommand = "sh -c \(ShellQuoting.quoted("(\n\(script)\n) </dev/null >/dev/null 2>&1 &"))"

    static let script = #"""
        # Count payload limits in bytes on both BSD and GNU shells; names themselves remain UTF-8 data.
        LC_ALL=C
        export LC_ALL
        pane_pid=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_pid}') || exit 0
        location=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_id}.#{pane_id}') || exit 0
        config=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
        records=$config/sessions
        record= shown= session_id= transcript= transcript_size= title_line= shown_json= shown_title=
        encoder=$(command -v base64)
        while kill -0 "$pane_pid" 2>/dev/null; do
          [ -f "$record" ] || record=$(grep -lF "\"tmux\":\"$location\"" "$records"/*.json 2>/dev/null | head -n 1)
          json=
          [ -n "$record" ] && IFS= read -r json < "$record"
          case $json in
          *'"status":"'*'}')
            status=${json#*'"status":"'} reason=
            case $json in *'"waitingFor":"'*) reason=${json#*'"waitingFor":"'} ;; esac
            activity=${status%%'"'*}:${reason%%'"'*}
            if [ "$activity" != "$shown" ]; then
              tmux set-option -wq -t "$TMUX_PANE" \#(RemoteCLIActivityTitle.optionName) "$activity" \; refresh-client -S
              shown=$activity
            fi
            ;;
          esac
          case $json in
          *'"sessionId":"'*'}')
            sid=${json#*'"sessionId":"'} sid=${sid%%'"'*}
            case $sid in ''|*[!a-zA-Z0-9-]*) sleep 1; continue ;; esac
            [ "${#sid}" -eq 36 ] || { sleep 1; continue; }
            if [ "$sid" != "$session_id" ]; then
              session_id=$sid transcript= transcript_size= title_line=
            fi
            if [ ! -f "$transcript" ]; then
              for file in "$config"/projects/*/"$session_id.jsonl"; do
                [ -f "$file" ] && { transcript=$file; break; }
              done
            fi
            if [ -f "$transcript" ]; then
              size=$(wc -c < "$transcript")
              if [ "$size" != "$transcript_size" ]; then
                latest=$(tail -c 65536 "$transcript" | grep -F '"type":"custom-title"' | tail -n 1)
                case $latest in *'}') title_line=$latest ;; esac
                transcript_size=$size
              fi
            fi
            [ "${#title_line}" -le 4096 ] || title_line=
            if [ "${#json}" -gt 8192 ]; then
              # Fall back to the activity option, not an old session record's activity.
              tmux set-option -uwq -t "$TMUX_PANE" \#(RemoteClaudeSessionTitle.optionName) \; refresh-client -S
              shown_json= shown_title=
            elif [ -n "$encoder" ] &&
               { [ "$json" != "$shown_json" ] || [ "$title_line" != "$shown_title" ]; }; then
              encoded_record=$(printf '%s' "$json" | "$encoder" | tr -d '\n')
              encoded_title=$(printf '%s' "$title_line" | "$encoder" | tr -d '\n')
              tmux set-option -wq -t "$TMUX_PANE" \#(RemoteClaudeSessionTitle.optionName) "$encoded_record:$encoded_title" \; refresh-client -S
              shown_json=$json shown_title=$title_line
            fi
            ;;
          esac
          sleep 1
        done
        """#
}
