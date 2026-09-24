#!/bin/zsh
set -euo pipefail

# Regenerates Branding/PNG and Branding/AppIcon.icns from the SVG sources in Branding/SVG.
project_directory="${0:A:h:h:h}"
svg_directory="$project_directory/Branding/SVG"
png_directory="$project_directory/Branding/PNG"
renderer="$project_directory/Scripts/Branding/render-svg-to-png.swift"

work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
iconset_directory="$work_directory/AppIcon.iconset"
mkdir -p "$iconset_directory" "$png_directory"

render_arguments=()
for point_size in 16 32 128 256 512; do
    render_arguments+=("$svg_directory/app-icon.svg" "$point_size" "$iconset_directory/icon_${point_size}x${point_size}.png")
    render_arguments+=("$svg_directory/app-icon.svg" "$((point_size * 2))" "$iconset_directory/icon_${point_size}x${point_size}@2x.png")
done
for pixel_width in 1024 512 256 128; do
    render_arguments+=("$svg_directory/app-icon.svg" "$pixel_width" "$png_directory/app-icon-$pixel_width.png")
    render_arguments+=("$svg_directory/app-icon-dark.svg" "$pixel_width" "$png_directory/app-icon-dark-$pixel_width.png")
done
for mark_name in mark mark-inverse mark-mono; do
    render_arguments+=("$svg_directory/$mark_name.svg" 512 "$png_directory/$mark_name-512.png")
done
for lockup_name in lockup-horizontal lockup-horizontal-inverse lockup-stacked lockup-stacked-inverse; do
    render_arguments+=("$svg_directory/$lockup_name.svg" 1200 "$png_directory/$lockup_name-1200.png")
done

swift "$renderer" "${render_arguments[@]}"
iconutil --convert icns "$iconset_directory" --output "$project_directory/Branding/AppIcon.icns"
echo "$project_directory/Branding/AppIcon.icns"
