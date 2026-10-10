#!/bin/zsh
set -euo pipefail

project_directory="${0:A:h:h}"
cd "$project_directory"
# The release workflow sets APP_VERSION from the tag and APP_BUILD_NUMBER from its run. A local build shows the commit
# it was built from, such as 1.1.0-3-gf45492c, read before this script generates any files. Its build number 0 is
# older than every release, so Check for updates still offers the latest one, but automatic checks are off by default:
# a development build is not interrupted by update offers or counted as an install of a release.
if [[ -n "${APP_VERSION:-}" ]]; then
    app_version="$APP_VERSION"
    build_number="${APP_BUILD_NUMBER:?APP_BUILD_NUMBER must be set with APP_VERSION}"
    checks_for_updates_automatically=true
else
    app_version="$("$project_directory/Scripts/Version/describe-development-version.sh")"
    build_number="${APP_BUILD_NUMBER:-0}"
    checks_for_updates_automatically=false
fi
python3 Scripts/Localization/compile_catalog.py
# Recreate this generated bundle: incremental SwiftPM builds can retain a removed language directory.
rm -rf "$project_directory/.build/release/JustSessions_JustSessions.bundle"
swift build -c release

app_directory="${1:-$project_directory/dist/JustSessions.app}"
if [[ "$app_directory" != *.app ]]; then
    print -u2 "The app bundle path must end in .app: $app_directory"
    exit 1
fi
# Once the app has been opened, macOS App Management refuses writes inside its bundle ("Operation not permitted"),
# but still allows removing the bundle. Each build assembles a fresh one.
rm -rf "$app_directory"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources" "$app_directory/Contents/Frameworks"
cp "$project_directory/.build/release/JustSessions" "$app_directory/Contents/MacOS/JustSessions"
install_name_tool -add_rpath @executable_path/../Frameworks "$app_directory/Contents/MacOS/JustSessions"
localization_resources="$project_directory/.build/release/JustSessions_JustSessions.bundle"
ditto "$localization_resources" "$app_directory/Contents/Resources/JustSessions_JustSessions.bundle"
# SwiftUI's standard controls look in Bundle.main; AppKit strings use the SwiftPM resource bundle.
# SwiftPM's native build system lays the bundle out flat; its default swiftbuild system uses Contents/Resources.
localization_directories=("$localization_resources"/*.lproj(N) "$localization_resources"/Contents/Resources/*.lproj(N))
if (( ${#localization_directories} == 0 )); then
    print -u2 "No localizations were found in $localization_resources"
    exit 1
fi
localization_identifiers=()
for localization_directory in "${localization_directories[@]}"; do
    ditto "$localization_directory" "$app_directory/Contents/Resources/${localization_directory:t}"
    localization_identifiers+=("${${localization_directory:t}%.lproj}")
done
swiftterm_resources="$project_directory/.build/release/SwiftTerm_SwiftTerm.bundle"
if [[ -d "$swiftterm_resources" ]]; then
    ditto "$swiftterm_resources" "$app_directory/Contents/Resources/SwiftTerm_SwiftTerm.bundle"
fi
cp -f "$project_directory/.build/checkouts/SwiftTerm/LICENSE" "$app_directory/Contents/Resources/SwiftTerm-LICENSE.txt"
# Ghostty's terminal reads its shell integration and terminfo from this bundle, and stops the app if it is missing.
ghostty_resources="$project_directory/.build/release/GhosttyKit_GhosttyTerminal.bundle"
if [[ ! -d "$ghostty_resources" ]]; then
    print -u2 "Ghostty's resource bundle was not found at $ghostty_resources"
    exit 1
fi
ditto "$ghostty_resources" "$app_directory/Contents/Resources/GhosttyKit_GhosttyTerminal.bundle"
cp -f "$project_directory/.build/checkouts/libghostty-spm/LICENSE" "$app_directory/Contents/Resources/libghostty-spm-LICENSE.txt"
cp -f "$project_directory/.build/checkouts/DisplayLink/LICENSE" "$app_directory/Contents/Resources/DisplayLink-LICENSE.txt"
# Everything Ghostty's prebuilt library links; see Branding/ThirdParty/Ghostty/README.md.
ditto "$project_directory/Branding/ThirdParty/Ghostty" "$app_directory/Contents/Resources/Ghostty-Licenses"
cp -f "$project_directory/Branding/ThirdParty/Octicons/LICENSE" "$app_directory/Contents/Resources/Octicons-LICENSE.txt"
# The font itself ships in the resource bundle above; keep its license with the other third-party licenses.
cp -f "$project_directory/Sources/JustSessions/Resources/Fonts/SymbolsNerdFontMono-LICENSE.txt" "$app_directory/Contents/Resources/SymbolsNerdFontMono-LICENSE.txt"
# Assets.car carries the light, dark and tinted icons for macOS 26; older macOS falls back to AppIcon.icns.
cp -f "$project_directory/Branding/Assets.car" "$app_directory/Contents/Resources/Assets.car"
cp -f "$project_directory/Branding/AppIcon.icns" "$app_directory/Contents/Resources/AppIcon.icns"
tmux_runtime_directory="$("$project_directory/Scripts/Tmux/build-runtime.sh")"
ditto "$tmux_runtime_directory" "$app_directory/Contents/Resources/Tmux"
sparkle_framework="$project_directory/.build/artifacts/Sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
    print -u2 "Sparkle.framework was not found at $sparkle_framework"
    exit 1
fi
ditto "$sparkle_framework" "$app_directory/Contents/Frameworks/Sparkle.framework"
cp -f "$project_directory/.build/artifacts/Sparkle/Sparkle/LICENSE" "$app_directory/Contents/Resources/Sparkle-LICENSE.txt"
cat >"$app_directory/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>JustSessions</string>
    <key>CFBundleDisplayName</key><string>JustSessions</string>
    <key>CFBundleIdentifier</key><string>dev.zichaoyang.justsessions</string>
    <key>CFBundleExecutable</key><string>JustSessions</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleShortVersionString</key><string>VERSION_PLACEHOLDER</string>
    <key>CFBundleVersion</key><string>BUILD_NUMBER_PLACEHOLDER</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>SUFeedURL</key><string>https://justsessions-update-feed.noether-lab.workers.dev/appcast.xml</string>
    <key>SUPublicEDKey</key><string>pTbuztMtV4TVr5xOu9ON8B3L2xsJJRf8q5zyMg7SaD8=</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUVerifyUpdateBeforeExtraction</key><true/>
</dict></plist>
PLIST
plutil -insert CFBundleLocalizations -json "$(python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "${localization_identifiers[@]}")" "$app_directory/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$app_directory/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$app_version" "$app_directory/Contents/Info.plist"
plutil -replace SUEnableAutomaticChecks -bool "$checks_for_updates_automatically" "$app_directory/Contents/Info.plist"
source_revision="$(git rev-parse HEAD)"
plutil -insert JustSessionsSourceRevision -string "$source_revision" "$app_directory/Contents/Info.plist"
codesign_identity="${CODE_SIGN_IDENTITY:--}"
if [[ "$codesign_identity" == "-" ]]; then
    codesign --force --sign "$codesign_identity" "$app_directory/Contents/Resources/Tmux/bin/tmux"
    codesign --force --deep --sign "$codesign_identity" "$app_directory"
else
    codesign --force --options runtime --timestamp --sign "$codesign_identity" "$app_directory/Contents/Resources/Tmux/bin/tmux"
    codesign --force --deep --options runtime --timestamp --sign "$codesign_identity" "$app_directory"
fi
python3 "$project_directory/Scripts/Tmux/verify-runtime.py" "$app_directory/Contents/Resources/Tmux"
echo "$app_directory"
