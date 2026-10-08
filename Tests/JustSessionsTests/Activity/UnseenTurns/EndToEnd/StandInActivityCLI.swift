import Foundation

/// Stand-ins for Claude Code and Codex that run in tmux and tell what they are doing the way the real CLIs do, so the
/// app reads them through its own paths. Each takes the session id the app starts it with. A line typed in its
/// terminal starts a turn, which lasts until the test writes how it ends to `$HOME/turn-ends/<session id>`; typing
/// `/exit` quits.
enum StandInActivityCLI {
    /// Keeps its entry in Claude Code's live registry, named by its own process as Claude Code's is: "busy" during a
    /// turn, then "idle", or "waiting" when the turn ends with "waiting", as at a permission prompt.
    static let claude = #"""
        #!/bin/sh
        # The tab starts the CLI with only its own folder on PATH.
        PATH=/usr/bin:/bin
        for argument in "$@"; do
            case "$argument" in ????????-????-????-????-????????????) session_id="$argument" ;; esac
        done
        registry="$HOME/.claude/sessions"
        turn_end="$HOME/turn-ends/$session_id"
        mkdir -p "$registry"
        report() {
            printf '{"pid":%d,"sessionId":"%s","status":"%s","waitingFor":"%s"}' "$$" "$session_id" "$1" "$2" > "$registry/$$.partial"
            mv "$registry/$$.partial" "$registry/$$.json"
        }
        report idle ""
        while IFS= read -r line; do
            [ "$line" = /exit ] && exit 0
            report busy ""
            until [ -f "$turn_end" ]; do sleep 0.05; done
            ending=$(cat "$turn_end")
            rm -f "$turn_end"
            if [ "$ending" = waiting ]; then report waiting "permission prompt"; else report idle ""; fi
        done
        """#

    /// Appends each turn's `task_started` and `task_complete` to its session's rollout file, as Codex does.
    static let codex = #"""
        #!/bin/sh
        # The tab starts the CLI with only its own folder on PATH.
        PATH=/usr/bin:/bin
        for argument in "$@"; do
            case "$argument" in ????????-????-????-????-????????????) session_id="$argument" ;; esac
        done
        rollout=$(find "$HOME/.codex/sessions" -name "rollout-*-$session_id.jsonl" | head -n 1)
        turn_end="$HOME/turn-ends/$session_id"
        record() {
            now=$(perl -MTime::HiRes=time -MPOSIX=strftime -e '$t = time; printf("%s.%03dZ", strftime("%Y-%m-%dT%H:%M:%S", gmtime($t)), ($t - int($t)) * 1000)')
            printf '{"timestamp":"%s","type":"event_msg","payload":{"type":"%s","turn_id":"stand-in-turn"}}\n' "$now" "$1" >> "$rollout"
        }
        while IFS= read -r line; do
            [ "$line" = /exit ] && exit 0
            record task_started
            until [ -f "$turn_end" ]; do sleep 0.05; done
            rm -f "$turn_end"
            record task_complete
        done
        """#
}
