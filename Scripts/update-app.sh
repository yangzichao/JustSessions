#!/bin/bash
set -euo pipefail

source_directory="$1"
application_bundle="$2"
application_pid="$3"
repository_url="$4"
result_file="$5"
log_file="$6"
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

cd "$source_directory"
if [[ "$(/usr/bin/git branch --show-current)" != "main" ]]; then
    echo "The source checkout is not on main."
    exit 1
fi
if [[ -n "$(/usr/bin/git status --porcelain)" ]]; then
    echo "The source checkout has uncommitted changes."
    exit 1
fi

/usr/bin/git fetch "$repository_url" main
if ! /usr/bin/git merge-base --is-ancestor HEAD FETCH_HEAD; then
    echo "The source checkout has commits that are not on GitHub main."
    exit 1
fi
/usr/bin/git merge --ff-only FETCH_HEAD

staging_directory="$(mktemp -d "$(dirname "$application_bundle")/.claudex-update.XXXXXX")"
./Scripts/build-app.sh "$staging_directory/claudex-macos.app"
/usr/bin/codesign --verify --deep --strict "$staging_directory/claudex-macos.app"

mv "$application_bundle" "$staging_directory/previous.app"
mv "$staging_directory/claudex-macos.app" "$application_bundle"
revision="$(/usr/bin/git rev-parse --short HEAD)"
printf 'success\nUpdated to GitHub revision %s.\n' "$revision" >"$result_file"
/usr/bin/open "$application_bundle"
