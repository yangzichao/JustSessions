# Settings and appearance

[Back to requirements](../README.md)

## Settings window

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| SET-01 | Settings is a sheet on the workspace window, not a window of its own. It opens from the sidebar footer, the app menu, or ⌘,; the menu uses the frontmost workspace window (also while a reading window has focus) and opens one when none is open. It closes with Done or a click outside. | `2c3e9c9` | `AppWideSheetPresentersTests` |
| SET-02 | Pages switch with a segmented control at the top: General, Appearance, Permissions, Help. Every page shares one size (`SettingsTabPage.size`) and scrolls inside it, so the sheet never changes size between pages or with the terminal font. Its width follows the interface size (SET-47); its height doesn't. | `2c3e9c9`, `ad34ae9`, `f333697`, `b20f964`, `879a87d` | `SettingsTabPageSizeTests`, `SettingsTabSwitcherTests` |
| SET-03 | An open Settings or Help sheet never blocks Quit or Sparkle's Install and Relaunch. Other sheets keep their normal protection. | `a00ee5a` | `SettingsSheetTerminationTests` |

## General

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| SET-20 | Interface language: Follow System (default), English, or Chinese; unmatched system languages fall back to English. | `77bdca4` | `AppLanguageStoreTests`, `AppLanguageEnvironmentTests` |
| SET-21 | Startup: reopen tabs at launch (default on) and launch at login (optional). | `3c634a3`, `110fd5d`, `f333697` | `TabReopeningSettingsStoreTests`, `LaunchAtLoginSettingsStoreTests` |
| SET-22 | Notifications: one switch per kind (ACT-43). Tabs: a CLI tab picker for each host, This Mac first, one for plain terminals (TMX-21), and what ⌘-clicking a file does (TRM-71). Sidebar: show subagents (DSC-08, default off), and **Show sessions from**, a box per CLI, all ticked by default (SBF-25). | `33931f7`, `e5f95f4`, `2ff2669`, `23c4377`, `9aabe60`, feature request, 7 November 2026 | `SessionNotificationPreferencesTests`, `TabCloseChoiceSettingsStoreTests`, `SidebarSubagentVisibilityTests`, `HiddenConversationProvidersTests` |
| SET-23 | Software update settings and About sit at the end of General: app and macOS versions, Check for updates, Release notes, Send feedback, Report an issue, Website, and GitHub. Release notes open under General with a back button, not as a page of their own. | `e619195`, `1ee0af5`, `603eec3`, `7e21d0d` | `AppReleaseHistoryTests`, `FeedbackLinksTests` |

## Appearance

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| SET-40 | App appearance is System, Light, or Dark. Themes are JustSessions, GitHub, Atom One, Tokyo Night, Catppuccin, and Gruvbox, each with light and dark colors. | `49ff832`, `6795ad1`, `932fd8a` | `AppAppearanceStoreTests`, `AppThemeStoreTests`, `AppThemeChooserTests` |
| SET-41 | Theme thumbnails show both versions split on a slant, and draw the tab bar as the app does. | `b41c696`, `82bbaed` | Manual |
| SET-42 | App and terminal appearance share one Appearance page, the terminal's colors right under the app theme. Restore Defaults sits in the Terminal heading and resets only the terminal. | `01d7971` | Manual |
| SET-43 | **Customize colors** changes the chosen theme's background, sidebar, fields and buttons, your messages, and text and accents, per light or dark version, applied as picked. Changes are stored as overrides on the built-in theme, stay with it when another is chosen, show "Customized" under its name, and **Reset** removes them. Saved colors are read one by one, so one unusable value drops only itself. | `efbc8df`, `ab06a47` | `AppThemeCustomizationTests` |
| SET-44 | Text stays readable on customized colors: a text color is made readable once; a surface that text can't stay readable on is refused with a note; any text color and going back to a theme's own color are always accepted. Terminals and the tab bar take color picks once picking pauses. | `efbc8df`, `ab06a47` | `AppThemeCustomizationTests`, `AppThemeReadabilityTests` |
| SET-45 | Selected sidebar rows and hovered group labels are opaque blends the theme computes, not translucent fills, so P3 displays don't lighten them below 4.5:1. | `16246c3` | `ThemeSurfaceRenderingTests` |
| SET-46 | Tab group colors come from the theme's palette and stay readable in every theme. | `39ee03b` | `TabGroupPaletteTests` |
| SET-47 | **Interface size** (90% to 150% in steps of 10%, default 100%) scales the app's own text, symbols, and the sizes that hold them in every window at once, as soon as it changes: the sidebar, tabs, preview, sheets, Settings, cards, and popovers. Terminals keep their own font size (TRM-42) and the conversation its reading text size (RDR-40). The sidebar's saved width is at 100% and shows at a larger interface size, so its rows hold as much of their titles, and as it is at a smaller one; sheet, card, and Settings page widths scale with every size. The tab bar keeps its height, so the tabs stay level with the window's buttons and the title bar's controls; its text and the tabs' widths scale. The system's own controls take the control size nearest the interface size: small at 90%, large from 120%, extra large from 140%. macOS ignores SwiftUI's Dynamic Type, so the app scales its type itself. | `879a87d` | `InterfaceSizeTests`; rendered at 90%, 100%, 125%, and 150% |

## Permissions

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| SET-60 | The Permissions page shows notifications, Full Disk Access (optional), Accessibility (optional), and, on macOS 15 and later, Local Network, each with a link to its System Settings page. | `01d7971`, `51aea5b` | `AppPermissionStatusTests` |
| SET-61 | Checking never shows a prompt: Full Disk Access is read by opening a file only it can read, Accessibility through `AXIsProcessTrusted`, and Local Network is only linked since macOS can't report it. The page checks again when shown and when the app becomes active. | `01d7971`, `51aea5b` | `FullDiskAccessProbeTests`, `AccessibilityTrustProbeTests` |
