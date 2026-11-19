import Foundation

extension StandInActivityCLI {
    static let pi = reportingThroughTheAppsExtension(
        startedWithTheExtension: #"[ -f "$extension" ]"#,
        waitingFor: piPromptTitle
    )
    static let piPromptTitle = "Allow rm -rf build?"

    static let opencode = reportingThroughTheAppsExtension(
        startedWithTheExtension: #"[ -f "$OPENCODE_TUI_CONFIG" ]"#,
        waitingFor: "permission"
    )

    private static func reportingThroughTheAppsExtension(startedWithTheExtension condition: String, waitingFor reason: String) -> String {
        #"""
        #!/bin/sh
        # The tab starts the CLI with only its own folder on PATH.
        PATH=/usr/bin:/bin
        while [ $# -gt 0 ]; do
            case "$1" in
                --session) session_id="$2"; shift ;;
                --extension) extension="$2"; shift ;;
            esac
            shift
        done
        reports="$JUSTSESSIONS_LIVE_SESSION_REPORTS"
        turn_end="$HOME/turn-ends/$session_id"
        report() {
            \#(condition) && [ -n "$reports" ] || return 0
            waiting_for=""
            [ -n "$2" ] && waiting_for=",\"waitingFor\":\"$2\""
            mkdir -p "$reports"
            printf '{"pid":%d,"sessionId":"%s","activity":"%s"%s}' "$$" "$session_id" "$1" "$waiting_for" > "$reports/$$.partial"
            mv "$reports/$$.partial" "$reports/$$.json"
        }
        report idle
        while IFS= read -r line; do
            if [ "$line" = /exit ]; then rm -f "$reports/$$.json"; exit 0; fi
            report working
            until [ -f "$turn_end" ]; do sleep 0.05; done
            ending=$(cat "$turn_end")
            rm -f "$turn_end"
            if [ "$ending" = waiting ]; then report waiting "\#(reason)"; else report idle; fi
        done
        """#
    }
}
