# Product principles and cross-cutting UI rules

[Back to requirements](README.md)

These hold everywhere in the app. A feature that breaks one needs an explicit decision, not just a pull request.

## Product

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| PRD-01 | Each CLI runs its own interface in an embedded native terminal. The app never replaces a CLI's TUI, configuration, or provider sign-in. | `65f5ade`, README | Manual |
| PRD-02 | Sessions are read from each CLI's own files. No JustSessions account, and no conversation is uploaded to a JustSessions service. | `c12d3bc`, [session storage](../guides/session-storage.md) | Manual |
| PRD-03 | One sidebar for six CLIs: Claude Code, Codex, Antigravity CLI, Kiro CLI, OpenCode, and Pi. Every one of them supports listing, preview, resume, deletion, and SSH hosts. Branch is offered for Claude Code, Codex, OpenCode, and Pi; Kiro CLI has none. | `9504055`, `12abb26`, `4197645` | `Adapters/*`, `Transcript/*`, `Deletion/*`, `Remote/*` |
| PRD-04 | Runs on macOS 14 or later, Apple Silicon. The bundled tmux is built for the macOS 14 deployment target; newer APIs fail the build and the runtime verifier rejects weak imports. | `47b99cf` | `BundledTmuxRuntimeTests` |
| PRD-05 | Sparkle is the only update path. A release is attached to its `v<major>.<minor>.<patch>` tag and ships a signed, notarized drag-to-Applications DMG. | `57cf8d5`, `d3f975a`, `ba344ab`, `3daec6f` | Manual |
| PRD-06 | The bundle identifier is `dev.zichaoyang.justsessions`, and `Info.plist` in `build-app.sh` matches `AppIdentity` and `Package.swift`. | `2054475`, `4c7df7a` | `AppBundleInfoContractTests` |
| PRD-07 | The interface is fully localized in English and Simplified Chinese. **Follow System** is the default; switching language updates the interface in place and leaves running terminal tabs alone. | `77bdca4`, `ddc62fc` | `Localization/*`, `make localization-check` |
| PRD-08 | A local build's version comes from `git describe`, with build number 0 and Sparkle's automatic checks off, so a development build is never offered or counted as a release install. | `33ec74c` | Manual |
| PRD-09 | The packaged app must find its resource bundles (localizations, Ghostty) in `Contents/Resources`. `make verify` opens the packaged app with the build folder's bundles hidden. | `ddc62fc`, `c71fab6`, `fb0e17a` | `make verify` launch check |
| PRD-27 | A program in a terminal tab can use the microphone, such as Claude Code's `/voice`. macOS asks for the app's permission, so `Info.plist` has `NSMicrophoneUsageDescription` and the release signature has the `com.apple.security.device.audio-input` entitlement, which the hardened runtime requires. Only the app carries it, not Sparkle's helpers. | Bug report, 29 October 2026 | `AppBundleInfoContractTests`, manual |

## Cross-cutting UI rules

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| PRD-20 | Keys a CLI uses (Escape, arrows, ⌘⌫, Control-B, and the like) are never bound as window-level shortcuts. New actions go into menus, context menus, and buttons; app shortcuts use Command, which never reaches a CLI, except ⌘←, ⌘→, ⌘⌫, and ⌘Z, which a terminal sends as line editing keys (TRM-66). | `ca9e282`, project decision of 24 September 2026, `80b9c00` | Manual |
| PRD-21 | Every piece of app text reads at 4.5:1 or better on the surface it sits on, in every theme, including selected rows and hovered labels. | `16246c3`, `ab06a47` | `AppThemeReadabilityTests`, `ThemeSurfaceRenderingTests` |
| PRD-22 | Views use the theme palette's text colors and themed button styles, never the system's secondary or tertiary text styles or unthemed controls. Buttons give the same press feedback throughout the app. | `16246c3`, `0acde62`, `39ee03b` | `ThemeTextColorContractTests` |
| PRD-23 | A click on the window around a sheet, alert, or confirmation dialog closes it as Cancel would. The title bar, where the tab bar sits, counts as outside. File panels keep the system behavior. | `44433ed`, `24dc09a` | `DismissesOnClickOutsideTests`, `SheetClickOutsideMonitorTests` |
| PRD-24 | Long explanations live behind a `?` help popover beside the control, not as static text under it. Status a user must see, such as a permission state, stays visible. | `0a054a6`, `8de8f80` | Manual |
| PRD-25 | Tabs, tab groups, split view, zoom, and the tab hover card follow Chrome's behavior unless a terminal needs otherwise. Where they differ, the difference is written down (see [split view](terminal/split-view.md)). | `82bbaed`, `ccf1df7`, `08525c2`, `19b4af9` | `Terminal/Tabs/*`, `Terminal/Split/*` |
| PRD-26 | Every user-facing action that changes or removes data asks first, and a remote deletion says it is permanent. Ticking **Delete the session when its tab closes** in the New session sheet is that question for the session it starts, so closing its tab deletes it without asking again (DSC-56). | `c84aeba`, `0845ae2`, `15cf5192` | `SessionDeletionConfirmationTextTests`, `DeletingWhenTabClosesTests` |
