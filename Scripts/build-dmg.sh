#!/bin/zsh
set -euo pipefail

# Packages a built app into a drag-to-Applications disk image.
project_directory="${0:A:h:h}"
app_path="${1:-$project_directory/dist/JustSessions.app}"
dmg_path="${2:-$project_directory/dist/JustSessions.dmg}"
volume_name="JustSessions"

if [[ ! -d "$app_path" ]]; then
    print -u2 "App bundle was not found at $app_path"
    exit 1
fi

staging_directory="$(mktemp -d)"
trap 'rm -rf "$staging_directory"' EXIT
ditto "$app_path" "$staging_directory/${app_path:t}"
ln -s /Applications "$staging_directory/Applications"

rm -f "$dmg_path"
hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_directory" \
    -fs HFS+ \
    -format UDZO \
    "$dmg_path"

codesign_identity="${CODE_SIGN_IDENTITY:--}"
if [[ "$codesign_identity" != "-" ]]; then
    codesign --force --timestamp --sign "$codesign_identity" "$dmg_path"
fi
echo "$dmg_path"
