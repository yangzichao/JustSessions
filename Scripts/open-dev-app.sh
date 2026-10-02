#!/bin/zsh
set -euo pipefail

# Opens the app bundle at $1 on its new build. `open` alone only brings a copy already running from that bundle to the
# front, still on the old build, so that copy quits first. Quitting saves its tabs, which reopen on launch.
app_directory="${1:A}"
running_executable_pattern="^$app_directory/Contents/MacOS/JustSessions"

if pgrep -f "$running_executable_pattern" >/dev/null; then
    osascript -e "tell application \"$app_directory\" to quit"
    for _ in {1..50}; do
        pgrep -f "$running_executable_pattern" >/dev/null || break
        sleep 0.2
    done
    if pgrep -f "$running_executable_pattern" >/dev/null; then
        print -u2 "JustSessions running from $app_directory did not quit within 10 seconds."
        exit 1
    fi
fi

open "$app_directory"
