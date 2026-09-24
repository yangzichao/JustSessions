#!/bin/zsh
set -euo pipefail

project_directory="${0:A:h:h}"
cd "$project_directory"
swift build -c release

app_directory="$project_directory/dist/Conversation Manager.app"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp "$project_directory/.build/release/ConversationManager" "$app_directory/Contents/MacOS/ConversationManager"
cat > "$app_directory/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>Conversation Manager</string>
    <key>CFBundleDisplayName</key><string>Conversation Manager</string>
    <key>CFBundleIdentifier</key><string>dev.zichaoyang.conversation-manager</string>
    <key>CFBundleExecutable</key><string>ConversationManager</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
echo "$app_directory"
