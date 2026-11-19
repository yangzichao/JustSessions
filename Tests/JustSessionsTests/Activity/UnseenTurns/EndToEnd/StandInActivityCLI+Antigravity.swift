import Foundation

extension StandInActivityCLI {
    static let antigravity = #"""
        #!/bin/sh
        # The tab starts the CLI with only its own folder on PATH.
        PATH=/usr/bin:/bin
        while [ $# -gt 0 ]; do
            case "$1" in
                --conversation) session_id="$2"; shift ;;
            esac
            shift
        done
        database="$HOME/.gemini/antigravity-cli/conversations/$session_id.db"
        turn_end="$HOME/turn-ends/$session_id"
        next_step() { sqlite3 "$database" 'SELECT coalesce(max(idx), -1) + 1 FROM steps'; }
        add_step() { sqlite3 "$database" "INSERT INTO steps (idx, step_type, status, step_payload) VALUES ($(next_step), $1, $2, x'')"; }
        # Field 1 says the execution finished; field 3 names its last step, in one varint byte while below 128.
        end_execution() {
            last_step=$(printf '18%02x' $(( $(next_step) - 1 )))
            sqlite3 "$database" "INSERT INTO executor_metadata (idx, data) VALUES ((SELECT coalesce(max(idx), -1) + 1 FROM executor_metadata), x'0804$last_step')"
        }
        waiting=false
        while IFS= read -r line; do
            [ "$line" = /exit ] && exit 0
            if [ "$waiting" = true ]; then
                sqlite3 "$database" 'UPDATE steps SET status = 3 WHERE status = 9'
                waiting=false
            else
                add_step 14 3
            fi
            until [ -f "$turn_end" ]; do sleep 0.05; done
            ending=$(cat "$turn_end")
            rm -f "$turn_end"
            if [ "$ending" = waiting ]; then
                add_step 132 9
                waiting=true
            else
                add_step 15 3
                end_execution
            fi
        done
        """#
}
