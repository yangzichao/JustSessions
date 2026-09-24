#!/bin/zsh
set -euo pipefail

project_directory="${0:A:h:h}"
cd "$project_directory"
swift build -c release

app_directory="$project_directory/dist/claudex-macos.app"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp "$project_directory/.build/release/ClaudexMacOS" "$app_directory/Contents/MacOS/ClaudexMacOS"
swiftterm_resources="$project_directory/.build/release/SwiftTerm_SwiftTerm.bundle"
if [[ -d "$swiftterm_resources" ]]; then
    ditto "$swiftterm_resources" "$app_directory/Contents/Resources/SwiftTerm_SwiftTerm.bundle"
fi
cp -f "$project_directory/.build/checkouts/SwiftTerm/LICENSE" "$app_directory/Contents/Resources/SwiftTerm-LICENSE.txt"
cat > "$app_directory/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>claudex-macos</string>
    <key>CFBundleDisplayName</key><string>claudex-macos</string>
    <key>CFBundleIdentifier</key><string>dev.zichaoyang.claudex-macos</string>
    <key>CFBundleExecutable</key><string>ClaudexMacOS</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.8.0</string>
    <key>CFBundleVersion</key><string>8</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$app_directory"
echo "$app_directory"
