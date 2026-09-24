#!/bin/zsh
set -euo pipefail

project_directory="${0:A:h:h}"
cd "$project_directory"
swift build -c release

app_directory="${1:-$project_directory/dist/JustSessions.app}"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources" "$app_directory/Contents/Frameworks"
cp "$project_directory/.build/release/JustSessions" "$app_directory/Contents/MacOS/JustSessions"
install_name_tool -add_rpath @executable_path/../Frameworks "$app_directory/Contents/MacOS/JustSessions"
swiftterm_resources="$project_directory/.build/release/SwiftTerm_SwiftTerm.bundle"
if [[ -d "$swiftterm_resources" ]]; then
    ditto "$swiftterm_resources" "$app_directory/Contents/Resources/SwiftTerm_SwiftTerm.bundle"
fi
cp -f "$project_directory/.build/checkouts/SwiftTerm/LICENSE" "$app_directory/Contents/Resources/SwiftTerm-LICENSE.txt"
cp -f "$project_directory/Branding/AppIcon.icns" "$app_directory/Contents/Resources/AppIcon.icns"
sparkle_framework="$project_directory/.build/artifacts/Sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
    print -u2 "Sparkle.framework was not found at $sparkle_framework"
    exit 1
fi
ditto "$sparkle_framework" "$app_directory/Contents/Frameworks/Sparkle.framework"
cp -f "$project_directory/.build/artifacts/Sparkle/Sparkle/LICENSE" "$app_directory/Contents/Resources/Sparkle-LICENSE.txt"
build_number="${APP_BUILD_NUMBER:-20}"
app_version="${APP_VERSION:-0.16.0}"
cat > "$app_directory/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>JustSessions</string>
    <key>CFBundleDisplayName</key><string>JustSessions</string>
    <key>CFBundleIdentifier</key><string>dev.zichaoyang.justsessions</string>
    <key>CFBundleExecutable</key><string>JustSessions</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.16.0</string>
    <key>CFBundleVersion</key><string>BUILD_NUMBER_PLACEHOLDER</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>SUFeedURL</key><string>https://github.com/yangzichao/JustSessions/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key><string>pTbuztMtV4TVr5xOu9ON8B3L2xsJJRf8q5zyMg7SaD8=</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUVerifyUpdateBeforeExtraction</key><true/>
</dict></plist>
PLIST
plutil -replace CFBundleVersion -string "$build_number" "$app_directory/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$app_version" "$app_directory/Contents/Info.plist"
source_revision="$(git rev-parse HEAD)"
plutil -insert JustSessionsSourceRevision -string "$source_revision" "$app_directory/Contents/Info.plist"
codesign_identity="${CODE_SIGN_IDENTITY:--}"
if [[ "$codesign_identity" == "-" ]]; then
    codesign --force --deep --sign "$codesign_identity" "$app_directory"
else
    codesign --force --deep --options runtime --timestamp --sign "$codesign_identity" "$app_directory"
fi
echo "$app_directory"
