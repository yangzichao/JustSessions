# Branding

The JustSessions mark is one conversation bubble holding three dots in the original CLI colors: orange for Claude Code, blue for Codex, and purple for Antigravity. The mark keeps those three dots as more CLIs are added. Their hues match `ConversationProvider.tintColor`.

## Files

`SVG/` holds the sources. Everything else is generated from them.

| File | Use |
| --- | --- |
| `app-icon.svg` | macOS app icon on the 1024px grid (824px body, 100px inset). Source of `AppIcon.icns`. |
| `app-icon-dark.svg` | Dark variant for dark backgrounds, websites, and social previews. |
| `mark.svg` / `mark-inverse.svg` | Mark without the icon background, for light / dark backgrounds. |
| `mark-mono.svg` | Single-color template with the dots knocked out. Tint it freely, e.g. as a menu bar template image. |
| `lockup-horizontal*.svg` / `lockup-stacked*.svg` | Mark plus wordmark. The wordmark is Geist SemiBold (SIL OFL 1.1), outlined, so no font is needed to render it. |

`PNG/` has rasterized exports, and `AppIcon.icns` is copied into the app bundle by `Scripts/build-app.sh`.

## Palette

| Name | Hex |
| --- | --- |
| Ink | `#15171C` |
| Orange | `#FF8A1F` |
| Blue | `#2F6BFF` |
| Purple | `#A64DF0` |
| White | `#FFFFFF` |

The default light app theme and website use warm neutral surfaces: content `#FCFBF8`, sidebar `#F3F1EC`, raised controls `#FFFFFF`, and user messages `#F1EDE6`. Primary actions use Ink. App theme values live in `Sources/JustSessions/Models/Appearance/Themes/ThemeColors/JustSessionsThemeColors.swift`; the website mirrors them in `website/styles/app-theme.css`.

Additional CLI tints are Kiro `#E0408A`, OpenCode `#12A08F`, and Pi `#3F9F2F`. These identify tools; they do not replace the app's neutral theme.

## Regenerate

After editing an SVG, rebuild the PNGs and `AppIcon.icns`:

```sh
./Scripts/Branding/build-brand-assets.sh
```

It uses AppKit's SVG renderer and `iconutil`, so it only needs macOS and the Swift toolchain. AppKit ignores `font-family` and `font-weight` in SVG `<text>`, so keep any text outlined.
