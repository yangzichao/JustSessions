#!/bin/zsh
set -euo pipefail

# Regenerates the app icon (Branding/Assets.car, Branding/AppIcon.icns) from Branding/AppIcon.icon,
# and Branding/PNG from that icon and the SVG sources in Branding/SVG.
# Needs Xcode 26 or later: actool compiles the Icon Composer document and ictool renders it.
project_directory="${0:A:h:h:h}"
icon_document="$project_directory/Branding/AppIcon.icon"
svg_directory="$project_directory/Branding/SVG"
png_directory="$project_directory/Branding/PNG"
renderer="$project_directory/Scripts/Branding/render-svg-to-png.swift"
icon_inset_tool="$project_directory/Scripts/Branding/inset-app-icon-png.swift"
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"

work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
compiled_directory="$work_directory/Compiled"
mkdir -p "$compiled_directory" "$png_directory"

# Assets.car holds the light, dark and tinted icons for macOS 26; AppIcon.icns is the fallback for older macOS.
xcrun actool "$icon_document" --compile "$compiled_directory" --app-icon AppIcon \
    --enable-on-demand-resources NO --development-region en --target-device mac --platform macosx \
    --minimum-deployment-target 14.0 --output-partial-info-plist "$work_directory/AppIcon-Info.plist" > /dev/null
cp -f "$compiled_directory/Assets.car" "$compiled_directory/AppIcon.icns" "$project_directory/Branding/"

inset_arguments=()
for appearance in light dark; do
    rendition=Default
    png_prefix=app-icon
    if [[ "$appearance" == dark ]]; then
        rendition=Dark
        png_prefix=app-icon-dark
    fi
    "$ictool" "$icon_document" --export-image --output-file "$work_directory/$appearance.png" \
        --platform macOS --rendition "$rendition" --width 1024 --height 1024 --scale 1 > /dev/null
    for pixel_width in 1024 512 256 128; do
        inset_arguments+=("$work_directory/$appearance.png" "$pixel_width" "$png_directory/$png_prefix-$pixel_width.png")
    done
done
swift "$icon_inset_tool" "${inset_arguments[@]}"

render_arguments=()
for mark_name in mark mark-mono; do
    render_arguments+=("$svg_directory/$mark_name.svg" 512 "$png_directory/$mark_name-512.png")
done
for lockup_name in lockup-horizontal lockup-horizontal-inverse lockup-stacked lockup-stacked-inverse; do
    render_arguments+=("$svg_directory/$lockup_name.svg" 1200 "$png_directory/$lockup_name-1200.png")
done
swift "$renderer" "${render_arguments[@]}"

echo "$project_directory/Branding/Assets.car"
echo "$project_directory/Branding/AppIcon.icns"
