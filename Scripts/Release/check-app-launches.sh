#!/bin/zsh
set -euo pipefail

# Opens a packaged app and fails if it stops within a few seconds.
# SwiftPM resource accessors fall back to this machine's absolute .build path, which users do not have.
# The release build's resource bundles are hidden while the app starts, so the app must find its own copies.
project_directory="${0:A:h:h:h}"
app_path="${1:-$project_directory/dist/JustSessions.app}"
seconds_to_stay_running="${2:-8}"

if [[ ! -d "$app_path" ]]; then
    print -u2 "App bundle was not found at $app_path"
    exit 1
fi
executable_name="$(plutil -extract CFBundleExecutable raw "$app_path/Contents/Info.plist")"
# Ghostty's terminal stops the app when its resource bundle is missing, but only once a tab opens, which this launch
# never does; so the bundle the app looks for in its own resources is checked here.
# SwiftPM's native build system lays the bundle out flat; its default swiftbuild system uses Contents/Resources.
ghostty_bundle="$app_path/Contents/Resources/GhosttyKit_GhosttyTerminal.bundle"
ghostty_resources_found=false
for ghostty_resources in "$ghostty_bundle" "$ghostty_bundle/Contents/Resources"; do
    if [[ -d "$ghostty_resources/Ghostty" && -d "$ghostty_resources/terminfo" ]]; then ghostty_resources_found=true; fi
done
if [[ "$ghostty_resources_found" != true ]]; then
    print -u2 "Ghostty's shell integration and terminfo were not found in $ghostty_bundle"
    exit 1
fi

# .build/release is a symlink to the architecture's build directory; the app records the resolved path.
release_build_directory="${${:-$project_directory/.build/release}:A}"
hidden_bundles_directory="$(mktemp -d)"
launch_log="$hidden_bundles_directory/launch.log"
app_process_id=""
restore_build_bundles() {
    if [[ -n "$app_process_id" ]]; then
        kill "$app_process_id" 2>/dev/null || true
    fi
    for hidden_bundle in "$hidden_bundles_directory"/*.bundle(N); do
        mv "$hidden_bundle" "$release_build_directory/"
    done
    rm -rf "$hidden_bundles_directory"
}
trap restore_build_bundles EXIT
for build_bundle in "$release_build_directory"/*.bundle(N); do
    mv "$build_bundle" "$hidden_bundles_directory/"
done

# On a developer's Mac, reopening the last quit's tabs could resume CLIs in tmux that outlive this check, and the
# offer to report a crash would mark the developer's own crashes as offered.
# The argument domain needs a plist boolean: a bare NO reads as a string, which the setting ignores.
"$app_path/Contents/MacOS/$executable_name" -reopensTabsAtLaunch '<false/>' -offersCrashReportsAtLaunch '<false/>' \
    >"$launch_log" 2>&1 &
app_process_id=$!
for _ in {1..$seconds_to_stay_running}; do
    if ! kill -0 "$app_process_id" 2>/dev/null; then
        exit_status=0
        wait "$app_process_id" || exit_status=$?
        app_process_id=""
        print -u2 "$app_path stopped during launch with status $exit_status:"
        tail -n 20 "$launch_log" >&2
        exit 1
    fi
    sleep 1
done
echo "$app_path kept running for $seconds_to_stay_running seconds."
