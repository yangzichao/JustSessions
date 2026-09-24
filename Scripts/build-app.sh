#!/bin/zsh
set -euo pipefail

project_directory="${0:A:h:h}"
cd "$project_directory"
swift build -c release

app_directory="${1:-$project_directory/dist/JustSessions.app}"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp "$project_directory/.build/release/JustSessions" "$app_directory/Contents/MacOS/JustSessions"
swiftterm_resources="$project_directory/.build/release/SwiftTerm_SwiftTerm.bundle"
if [[ -d "$swiftterm_resources" ]]; then
    ditto "$swiftterm_resources" "$app_directory/Contents/Resources/SwiftTerm_SwiftTerm.bundle"
fi
cp -f "$project_directory/.build/checkouts/SwiftTerm/LICENSE" "$app_directory/Contents/Resources/SwiftTerm-LICENSE.txt"
cp -f "$project_directory/Scripts/update-app.sh" "$app_directory/Contents/Resources/update-app.sh"
cat > "$app_directory/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>JustSessions</string>
    <key>CFBundleDisplayName</key><string>JustSessions</string>
    <key>CFBundleIdentifier</key><string>dev.zichaoyang.coca-codex</string>
    <key>CFBundleExecutable</key><string>JustSessions</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.16.0</string>
    <key>CFBundleVersion</key><string>19</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
source_revision="$(git rev-parse HEAD)"
plutil -insert JustSessionsSourceRevision -string "$source_revision" "$app_directory/Contents/Info.plist"
plutil -insert CocaCodexSourceRevision -string "$source_revision" "$app_directory/Contents/Info.plist"
codesign --force --deep --sign - "$app_directory"
echo "$app_directory"
