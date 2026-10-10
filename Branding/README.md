# Branding

The JustSessions mark is three comic speech bubbles stacked with ink outlines: purple at the back, orange in the middle, and white in front. The front bubble holds three dots in the original CLI colors: orange for Claude Code, blue for Codex, and purple for Antigravity. The mark keeps those three dots as more CLIs are added. Their hues match `ConversationProvider.tintColor`.

## Files

`AppIcon.icon` and `SVG/` hold the sources. Everything else is generated from them.

| File | Use |
| --- | --- |
| `AppIcon.icon` | macOS app icon as an Icon Composer document: the mark on a halftone panel. The light appearance uses a paper panel with ink halftone; the dark appearance uses an ink panel with paper halftone. macOS 26 derives the clear and tinted styles. Open it in Icon Composer (bundled with Xcode 26) to edit it. Source of `Assets.car`, `AppIcon.icns`, and the `app-icon*.png` exports. |
| `mark.svg` | Mark without the icon background, for light and dark backgrounds: on a dark background the ink outline reads as a gap between the bubbles. |
| `mark-mono.svg` | Single-color template with the outlines and dots knocked out. Tint it freely, e.g. as a menu bar template image. |
| `lockup-horizontal*.svg` / `lockup-stacked*.svg` | Mark plus wordmark, in Ink or, for `-inverse`, white. The wordmark is Geist SemiBold (SIL OFL 1.1), outlined, so no font is needed to render it. |

`PNG/` has rasterized exports. `app-icon-*.png` and `app-icon-dark-*.png` are the light and dark appearances on the 1024px macOS grid (824px body, 100px inset). `Scripts/build-app.sh` copies `Assets.car` and `AppIcon.icns` into the app bundle: macOS 26 reads the light, dark, and tinted icons from `Assets.car`, and older macOS uses `AppIcon.icns`.

## Palette

| Name | Hex |
| --- | --- |
| Ink | `#15171C` |
| Orange | `#FF8A1F` |
| Blue | `#2F6BFF` |
| Purple | `#A64DF0` |
| White | `#FFFFFF` |
| Paper | `#F4EFE4` |

The default light app theme and website use warm neutral surfaces: content `#FCFBF8`, sidebar `#F3F1EC`, raised controls `#FFFFFF`, and user messages `#F1EDE6`. Primary actions use Ink. App theme values live in `Sources/JustSessions/Models/Appearance/Themes/ThemeColors/JustSessionsThemeColors.swift`; the website mirrors them in `website/styles/app-theme.css`.

Additional CLI tints are Kiro `#E0408A`, OpenCode `#12A08F`, and Pi `#3F9F2F`. These identify tools; they do not replace the app's neutral theme.

## Regenerate

After editing `AppIcon.icon` or an SVG, rebuild `Assets.car`, `AppIcon.icns`, and the PNGs:

```sh
./Scripts/Branding/build-brand-assets.sh
```

It needs Xcode 26 or later: `actool` compiles `AppIcon.icon`, and `ictool` from Icon Composer renders the PNGs. The SVGs use AppKit's SVG renderer, which ignores `font-family` and `font-weight` in SVG `<text>`, so keep any text outlined. `Assets.car` differs byte for byte on every run, so commit it only when the icon changed.
