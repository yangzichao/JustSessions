import Foundation

enum StandInActivityCLI {
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
