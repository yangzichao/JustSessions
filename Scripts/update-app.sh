#!/bin/bash
set -euo pipefail

archive="$1"
application_bundle="$2"
application_pid="$3"
expected_revision="$4"
expected_sha256="$5"
result_file="$6"
log_file="$7"
download_directory="$8"
staging_directory=""

mkdir -p "$(dirname "$result_file")" "$(dirname "$log_file")"
exec >"$log_file" 2>&1

finish_update() {
    local exit_status=$?
    trap - EXIT
    if (( exit_status != 0 )); then
        if [[ -n "$staging_directory" && -d "$staging_directory/previous.app" ]]; then
            if [[ -d "$application_bundle" ]]; then
                mv "$application_bundle" "$staging_directory/failed.app"
            fi
            mv "$staging_directory/previous.app" "$application_bundle"
        fi
        printf 'failure\nThe update could not finish. Details: %s\n' "$log_file" >"$result_file"
        if [[ -d "$application_bundle" ]]; then /usr/bin/open "$application_bundle" || true; fi
    fi
    if [[ -n "$staging_directory" && -d "$staging_directory" ]]; then
        rm -rf "$staging_directory"
    fi
    if [[ "$(basename "$download_directory")" == JustSessions-update-* && -d "$download_directory" ]]; then
        rm -rf "$download_directory"
    fi
    exit "$exit_status"
}
trap finish_update EXIT

for (( attempt = 0; attempt < 120; attempt++ )); do
    if ! kill -0 "$application_pid" 2>/dev/null; then break; fi
    sleep 0.5
done
if kill -0 "$application_pid" 2>/dev/null; then
    echo "The app did not exit within 60 seconds."
    exit 1
fi

actual_sha256="$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "The downloaded archive failed its SHA-256 check."
    exit 1
fi

staging_directory="$(mktemp -d "$(dirname "$application_bundle")/.JustSessions-update.XXXXXX")"
/usr/bin/ditto -x -k "$archive" "$staging_directory"
new_bundle="$staging_directory/JustSessions.app"
if [[ ! -d "$new_bundle" ]]; then
    echo "The archive does not contain JustSessions.app."
    exit 1
fi
/usr/bin/codesign --verify --deep --strict "$new_bundle"
bundle_identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$new_bundle/Contents/Info.plist")"
archive_revision="$(/usr/bin/plutil -extract JustSessionsSourceRevision raw "$new_bundle/Contents/Info.plist")"
if [[ "$bundle_identifier" != "dev.zichaoyang.coca-codex" || "$archive_revision" != "$expected_revision" ]]; then
    echo "The archive contains an unexpected app or revision."
    exit 1
fi

mv "$application_bundle" "$staging_directory/previous.app"
mv "$new_bundle" "$application_bundle"
printf 'success\nUpdated to GitHub revision %s.\n' "${expected_revision:0:7}" >"$result_file"
/usr/bin/open "$application_bundle"
